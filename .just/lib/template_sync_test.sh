#!/usr/bin/env bash
# Test suite for template synchronization system
#
# Two fixture modes share this runner:
#
#   - update-script mode (legacy, fixtures 01-04): drives a patched copy of
#     template_update.sh with a mocked curl, as before
#   - recipe mode (fixtures 05+): drives the actual `just checksums_verify`
#     / `checksums_diff` recipes in a temp workspace holding a copy of the
#     real .just/template-sync.just, so the validate_filepath gates that
#     live in the recipe bodies are exercised too (#354 - flagged as a
#     coverage gap in the Claude review of #352, since template_update.sh
#     tests never touch the recipe-level gates)
#
# Fixture layout is shared: input/, manifest.json, template_versions/,
# expected_output.txt, expected_state/. Recipe fixtures add:
#
#   recipe         - required: recipe to run, first word is the recipe name
#                     and remaining words are its arguments (e.g.
#                     "checksums_verify" or "checksums_diff ../evil.txt")
#   expected_exit  - optional: expected exit code (default 0 for recipe
#                     mode; update-script mode ignores failures as before)
#   modules        - optional: space-separated .just module basenames to
#                     copy into the workspace and import (default:
#                     "template-sync"; e.g. "gh-process" or "claude
#                     template-sync"). Each module's import line lands in
#                     the scaffolded justfile.
#   bare_justfile  - optional: any content; when present the scaffolded
#                     workspace justfile omits `set positional-arguments
#                     := true`, exactly mirroring a derived repo whose
#                     root justfile never ships (#368). Pins the
#                     invariant: tracked modules must be self-contained -
#                     no recipe may depend on root-justfile configuration
#                     that doesn't ship (#367).
#   shims/         - optional: executable scripts copied into the
#                     workspace and prepended to PATH, shadowing both the
#                     harness's mock curl and real tools (the same PATH
#                     shim precedent wait_for_copilot_test.sh uses for
#                     gh/sleep). Fixture shims win over the harness mock
#                     because the whole workspace dir sits first on PATH.
#   stdin          - optional: file piped to the recipe's stdin, for
#                     recipes that prompt (copilot_rollback's selection
#                     read, #382). Absent, stdin is /dev/null, so a
#                     recipe run can never hang on a TTY waiting for
#                     input; recipes that never read stdin (the
#                     checksums_* fixtures) are unaffected by EOF.
set -euo pipefail

# shellcheck source=.just/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NORMAL='\033[0m'

readonly FIXTURES_DIR=".just/test/fixtures/template_sync"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

passed=0
failed=0

# Run a single test
run_test() {
	local test_name="$1"
	local test_dir="$FIXTURES_DIR/$test_name"

	if [[ ! -d "$test_dir" ]]; then
		echo -e "${RED}✗${NORMAL} $test_name - directory not found"
		(( failed += 1 ))
		return
	fi

	# Absolutize before we cd into the workspace, so fixture checks
	# below still resolve after the working directory changes
	test_dir="$(cd "$test_dir" && pwd)"

	# Recipe mode (#354): drive the real just recipes. Falls back to a
	# yellow skip (counted as a failure so the gap stays visible) when
	# just is not installed.
	if [[ -f "$test_dir/recipe" ]]; then
		run_recipe_test "$test_name" "$test_dir"
		return
	fi

	run_update_test "$test_name" "$test_dir"
}

# Write the shared mock curl into a target directory. Contract:
#   - a call without -o fails and serves nothing: the CHECKSUMS.json
#     branch sits inside the -o branch, so a manifest fetch without
#     -o falls through to failure too (both real call sites use -o;
#     noted in #377 after the branch nesting narrowed)
#   - a call with -o writes to the given output file; a URL ending
#     in .just/CHECKSUMS.json serves the fixture manifest
#   - with -o, any other URL serves template_versions/<basename> if
#     present
# Both the recipe-mode and update-script-mode mocks must honor this
# exact contract, so it lives in one place (Claude review of #360,
# finding 2 - it was two copy-pasted heredocs that could drift).
write_mock_curl() {
	local target_dir="$1"
	local mock_curl="$target_dir/curl"
	cat > "$mock_curl" <<'MOCK_EOF'
#!/usr/bin/env bash
# Mock curl for testing
if [[ "$*" == *"-o"* ]]; then
	# Extract output file: the argument after -o
	output_file=""
	next=0
	for arg in "$@"; do
		if [[ "$next" == 1 ]]; then
			output_file="$arg"
			break
		fi
		if [[ "$arg" == "-o" ]]; then
			next=1
		fi
	done
	# The URL is the last non-flag argument
	source_path=""
	for arg in "$@"; do
		if [[ "$arg" != -* && "$arg" != "$output_file" ]]; then
			source_path="$arg"
		fi
	done
	if [[ "$source_path" == *".just/CHECKSUMS.json" ]]; then
		manifest_path="${BASH_SOURCE[0]%/*}/manifest.json"
		if [[ -f "$manifest_path" ]]; then
			# The update-script mode points MANIFEST_FILE straight at
			# this fixture-copied manifest (sed patch), so source and
			# destination can be the same file - cat-ing a file onto
			# itself would truncate it. No-op in that case.
			if [[ ! "$manifest_path" -ef "$output_file" ]]; then
				cat "$manifest_path" > "$output_file"
			fi
			exit 0
		fi
		exit 1
	fi
	filename="${source_path##*/}"
	template_file="${BASH_SOURCE[0]%/*}/template_versions/$filename"
	if [[ -f "$template_file" ]]; then
		cat "$template_file" > "$output_file"
		exit 0
	fi
	exit 1
fi
exit 1
MOCK_EOF
	chmod +x "$mock_curl"
}

# Expected-output check shared by both fixture modes (#377): every
# non-empty line in expected_output.txt must appear, in order, in the
# normalized output. On a mismatch, builds the failure diagnostic in
# $output_mismatch - the first expected line with no match at/after
# the search position, plus both sides dumped with the exact
# normalization the matcher uses (mktemp/pid paths already scrubbed)
# - so a red fixture answers "what did it actually print" without a
# manual re-run (#376).
#
# Globals set: output_ok, output_mismatch
match_expected_output() {
	local output="$1" test_dir="$2" test_name="$3"
	output_ok=true
	output_mismatch=""
	[[ -f "$test_dir/expected_output.txt" ]] || return 0

	# Normalize output (remove color codes, blank lines, temp paths).
	# The mismatch dump below reuses this exact normalization so
	# expected and actual compare line for line.
	local normalized_output
	# shellcheck disable=SC2016  # awk script is intentionally single-quoted
	normalized_output=$(echo "$output" | LC_ALL=C awk '{ gsub(/\033\[[0-9;]*m/, ""); print }' | \
		grep -v "^$" | \
		sed 's|/tmp/[^[:space:]]*||g')

	# Every non-empty expected line must appear in order in the output
	local expected_lines=()
	local line
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -n "$line" ]] && expected_lines+=("$line")
	done < "$test_dir/expected_output.txt"

	if [[ ${#expected_lines[@]} -eq 0 ]]; then
		echo -e "${YELLOW}!${NORMAL} $test_name - expected_output.txt is empty, output not checked"
		return 0
	fi

	local search_start=1
	local line_num i=1
	for line in "${expected_lines[@]}"; do
		# -e: expected lines may start with dashes (e.g. diff output).
		# grep exits 1 when the line is missing - a handled case here,
		# not a crash - but under `set -euo pipefail` the substitution
		# would abort the whole suite before the mismatch could be
		# reported (a latent harness bug surfaced by the bare-justfile
		# fixtures, #368, whose whole point is failing recipes). The
		# `|| true` guard keeps the loop alive; the -z check below
		# reports the mismatch.
		line_num=$(echo "$normalized_output" | grep -nF -e "$line" | awk -F: -v s="$search_start" '$1 >= s {print $1; exit}') \
			|| true
		if [[ -z "$line_num" ]]; then
			output_ok=false
			# First-difference hint, then both sides, normalized (#376)
			output_mismatch=$(
				echo "      First unmatched expected line $i: \"$line\""
				echo "      (searched for it from normalized output line $search_start onward)"
				echo "      expected:"
				printf '        %s\n' "${expected_lines[@]}"
				echo "      actual:"
				if [[ -n "$normalized_output" ]]; then
					printf '%s\n' "$normalized_output" | sed 's/^/        /'
				fi
			)
			return 0
		fi
		search_start=$((line_num + 1))
		i=$((i + 1))
	done
}

# Expected-state check shared by both fixture modes (#377): every file
# under expected_state/ must exist in the workspace with an identical
# checksum. On a mismatch, records the offending path and reason in
# $state_mismatch so the failure report names the file the fix loop
# needs (the state counterpart of the output dump, #376).
#
# Globals set: state_ok, state_mismatch
verify_expected_state() {
	local workspace="$1" test_dir="$2"
	state_ok=true
	state_mismatch=""
	[[ -d "$test_dir/expected_state" ]] || return 0

	local expected_file
	# LC_ALL=C sort: find's order is filesystem-dependent, and the
	# mismatch report names the first offender, so the reported file
	# must not vary between runs or machines (review round, #433)
	while IFS= read -r expected_file; do
		# Quoted pattern (SC2295): the pre-extraction run_update_test
		# copy had drifted to the unquoted form (#377)
		local rel_path="${expected_file#"$test_dir"/expected_state/}"
		if [[ ! -f "$workspace/$rel_path" ]]; then
			state_ok=false
			state_mismatch="missing: $rel_path"
			return 0
		fi

		local expected_sum actual_sum
		expected_sum=$(compute_checksum "$expected_file")
		actual_sum=$(compute_checksum "$workspace/$rel_path")

		if [[ "$expected_sum" != "$actual_sum" ]]; then
			state_ok=false
			state_mismatch="differs: $rel_path"
			return 0
		fi
	done < <(find "$test_dir/expected_state" -type f | LC_ALL=C sort)
}

# Self-test for the shared matchers (review round, #433): the
# mismatch diagnostics only print when a fixture fails, and no
# fixture is supposed to fail, so the dump and state-reason paths
# would otherwise carry no coverage. Drives the helpers against a
# deliberately wrong scratch fixture and asserts the diagnostics
# fire - and stay silent on a clean run - reporting through the
# same passed/failed counters as a fixture. Applies the v10.5
# compliance suite's run-on-every-run self-test precedent here.
harness_selftest() {
	local scratch ws reasons=()
	scratch=$(mktemp -d)
	ws=$(mktemp -d)

	# Scratch fixture: two expected lines, one expected-state file
	mkdir -p "$scratch/expected_state/.just" "$ws/.just"
	printf 'alpha line\nomega line\n' > "$scratch/expected_output.txt"
	printf 'state one\n' > "$scratch/expected_state/.just/state.just"

	# Red case: second expected line missing from the output
	match_expected_output "alpha line" "$scratch" "harness_selftest"
	[[ "$output_ok" == false ]] || reasons+=("red output: output_ok not false")
	[[ "$output_mismatch" == *"First unmatched expected line 2"* ]] \
		|| reasons+=("red output: dump lacks first-unmatched marker")
	[[ "$output_mismatch" == *"searched for it from normalized output line 2 onward"* ]] \
		|| reasons+=("red output: dump lacks search-position hint")

	# Green case: every expected line present in order
	match_expected_output "alpha line
omega line" "$scratch" "harness_selftest"
	[[ "$output_ok" == true ]] || reasons+=("green output: output_ok not true")
	[[ -z "$output_mismatch" ]] || reasons+=("green output: mismatch detail not empty")

	# Green state: identical checksums
	printf 'state one\n' > "$ws/.just/state.just"
	verify_expected_state "$ws" "$scratch"
	[[ "$state_ok" == true ]] || reasons+=("green state: state_ok not true")
	[[ -z "$state_mismatch" ]] || reasons+=("green state: mismatch detail not empty")

	# Red state: content differs
	printf 'state one changed\n' > "$ws/.just/state.just"
	verify_expected_state "$ws" "$scratch"
	[[ "$state_ok" == false ]] || reasons+=("differs state: state_ok not false")
	[[ "$state_mismatch" == "differs: .just/state.just" ]] \
		|| reasons+=("differs state: got '$state_mismatch'")

	# Red state: file missing
	rm "$ws/.just/state.just"
	verify_expected_state "$ws" "$scratch"
	[[ "$state_ok" == false ]] || reasons+=("missing state: state_ok not false")
	[[ "$state_mismatch" == "missing: .just/state.just" ]] \
		|| reasons+=("missing state: got '$state_mismatch'")

	rm -rf "$scratch" "$ws"

	if [[ ${#reasons[@]} -eq 0 ]]; then
		echo -e "${GREEN}✓${NORMAL} harness_selftest"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} harness_selftest"
		local reason
		for reason in "${reasons[@]}"; do
			echo "    $reason"
		done
		(( failed += 1 ))
	fi
}

# Self-test for the security-boundary functions in common.sh (#382):
# validate_filepath is the gate every manifest key passes before any
# filesystem use (#347), and sanitize_for_display is what keeps a
# rejected key from spoofing output lines or injecting terminal escape
# sequences when it is printed. Recipe fixtures exercise both
# end-to-end through the checksums gates, but nothing pinned the
# specific rejection classes, and the escaping here is dense enough
# that a future "simplifying" edit could drop a class without any
# fixture going red. common.sh is already sourced at the top of this
# harness, so this asserts against the real shipped functions - the
# v10.6 harness_selftest precedent applied to product code. Reports
# through the same passed/failed counters as a fixture. Verified to
# behave identically on bash 3.2 (macOS) and bash 5 (CI).
security_boundary_selftest() {
	local reasons=()
	local path rc out

	# Accept: anything under the .just/ charter, including odd-but-
	# legal whole segment names like "..." (only whole ".." segments
	# are traversal)
	for path in ".just/foo.just" ".just/lib/common.sh" ".just/a/b.sh" ".just/..."; do
		rc=0
		validate_filepath "$path" || rc=$?
		[[ $rc -eq 0 ]] || reasons+=("expected accept, got reject: $path")
	done

	# Reject: anything not under .just/, relative or absolute (the
	# prefix check is what makes absolute paths safe)
	for path in "just/foo.just" "src/main.rs" "/etc/passwd" "../outside.sh"; do
		rc=0
		validate_filepath "$path" || rc=$?
		[[ $rc -ne 0 ]] || reasons+=("non-.just/ path accepted: $path")
	done

	# Reject: whole ".." segments - leading, mid-path, and final
	for path in ".just/../evil.sh" ".just/a/../b.sh" ".just/.."; do
		rc=0
		validate_filepath "$path" || rc=$?
		[[ $rc -ne 0 ]] || reasons+=("traversal accepted: $path")
	done

	# Reject: double quotes and backslashes (both break jq string
	# interpolation). A single quote is deliberately accepted: call
	# sites pass keys with jq --arg, which is quote-safe - pin that
	# so the rejection set can't creep wider without this going red.
	rc=0
	validate_filepath '.just/a"b.sh' || rc=$?
	[[ $rc -ne 0 ]] || reasons+=("double quote accepted: .just/a\"b.sh")
	rc=0
	validate_filepath '.just/a\b.sh' || rc=$?
	[[ $rc -ne 0 ]] || reasons+=("backslash accepted: .just/a\\b.sh")
	rc=0
	validate_filepath ".just/a'b.sh" || rc=$?
	[[ $rc -eq 0 ]] || reasons+=("single quote rejected (call sites use jq --arg): .just/a'b.sh")

	# Reject: control characters - tab, ESC, and the embedded newline
	# a NUL-delimited manifest key can carry (spoofs extra output
	# lines). Keep these out of the failure messages: printing them
	# would be the bug under test.
	for path in $'.just/a\tb.sh' $'.just/a\033b.sh' $'.just/a\nb.sh'; do
		rc=0
		validate_filepath "$path" || rc=$?
		[[ $rc -ne 0 ]] || reasons+=("control-character key accepted")
	done

	# sanitize_for_display: control bytes stripped, printables intact.
	# Two contracts: pure control bytes disappear, and an escape's
	# literal tail (here "[31m") survives - the function strips raw
	# control bytes only; the call sites' printf '%s' is what keeps
	# remaining literal text inert (Claude review of PR #434 asked
	# for the tail to be pinned explicitly).
	out=$(sanitize_for_display $'ab\ncd\033ef\tgh')
	[[ "$out" == "abcdefgh" ]] || reasons+=("sanitize_for_display: expected 'abcdefgh', got '$out'")
	out=$(sanitize_for_display $'\033[31mplain')
	[[ "$out" == "[31mplain" ]] || reasons+=("sanitize_for_display: expected literal tail '[31mplain', got '$out'")
	out=$(sanitize_for_display "plain-key.just")
	[[ "$out" == "plain-key.just" ]] || reasons+=("sanitize_for_display mangled plain text: '$out'")

	if [[ ${#reasons[@]} -eq 0 ]]; then
		echo -e "${GREEN}✓${NORMAL} security_boundary_selftest"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} security_boundary_selftest"
		local reason
		for reason in "${reasons[@]}"; do
			echo "    $reason"
		done
		(( failed += 1 ))
	fi
}

# Self-test for the CLEANED_FILES drift guard (#381, review of #438):
# the guard's failure modes - a typo'd entry, an unlisted removal, a
# column-0 comment example poisoning the scan, a vacuous both-sides-empty
# pass, and the rm -f vs rm -rf regex miss - were each found by hand, so
# a future edit to the extraction could regress with the next
# checksums_generate as the only signal. This drives the REAL
# generate_checksums.sh in scratch sandboxes - script, common.sh, and
# clean-template.just copies plus a one-file git repo, so the pass cases
# run generation end-to-end - and pins every one. The mini repo tracks
# one .just module and one lib script so both ls-files arrays are
# non-empty: macOS bash 3.2 with set -u treats empty-array expansion as
# an unbound variable, and the sandbox would crash after the guard
# instead of completing. Applies the v10.6 harness_selftest precedent
# to the guard. The version-drift guard rides the same sandboxes with
# synthetic version pairs - its red paths (a stale '# PR create'
# header, the notes-less derived-repo skip, an unparseable pair) are
# pinned here too (Claude review of #442). Reports through the same
# passed/failed counters as a fixture.
guard_selftest() {
	local reasons=()
	local root sb out err rc

	# git drives the mini repos and jq validates the generated manifest;
	# the generator itself hard-requires both. Missing tools skip with a
	# warning outside CI and fail inside it, mirroring compliance_test
	# (a skip cannot silently pass in the environment that gates PRs)
	if ! command -v git &>/dev/null || ! command -v jq &>/dev/null; then
		if [[ "${CI:-}" == "true" ]]; then
			echo -e "${RED}✗${NORMAL} guard_selftest - git/jq missing in CI"
			(( failed += 1 ))
		else
			echo -e "${YELLOW}!${NORMAL} guard_selftest - git/jq not installed, drift-guard coverage skipped"
		fi
		return 0
	fi

	root=$(mktemp -d)

	# Build one sandbox: real guard inputs plus a one-file git repo
	new_guard_sandbox() {
		local dir="$root/$1"
		mkdir -p "$dir/.just/lib"
		cp "$SCRIPT_DIR/generate_checksums.sh" "$SCRIPT_DIR/common.sh" "$dir/.just/lib/"
		cp "$SCRIPT_DIR/../clean-template.just" "$dir/.just/"
		# Synthetic version pair for the version-drift guard: the
		# guard reads only the '# PR create' header and the first
		# '### vX.Y' heading, so minimal synthetic files exercise it
		# without coupling the selftest to the real repo's mid-bump
		# state (Claude review of #442, item 2)
		printf '# PR create v9.9\n' >"$dir/.just/gh-process.just"
		printf '# synthetic notes\n\n### v9.9 - selftest entry\n' >"$dir/.just/RELEASE_NOTES.md"
		git -C "$dir" init -q
		printf '# sample module\n' >"$dir/.just/sample.just"
		git -C "$dir" add .just/sample.just .just/lib/common.sh
		git -C "$dir" -c user.email=selftest@local -c user.name=selftest \
			commit -qm 'sample v1.0'
		printf '%s' "$dir"
	}

	# Run the real generator in the sandbox, capturing rc/stdout/stderr
	run_guard() {
		out="$root/out.txt"
		err="$root/err.txt"
		rc=0
		(cd "$1" && bash .just/lib/generate_checksums.sh) >"$out" 2>"$err" || rc=$?
	}

	expect_rc() {
		[[ "$rc" -eq "$1" ]] || reasons+=("$2 (rc=$rc, want $1)")
	}

	expect_err() {
		grep -qF "$1" "$err" || reasons+=("$2")
	}

	expect_err_empty() {
		[[ ! -s "$err" ]] || reasons+=("$1: unexpected guard output: $(cat "$err")")
	}

	# In sync: full generation passes silently, banner rides in the JSON
	sb=$(new_guard_sandbox in_sync)
	run_guard "$sb"
	expect_rc 0 "in-sync: generation should pass"
	expect_err_empty "in-sync"
	jq -e . "$root/out.txt" >/dev/null 2>&1 \
		|| reasons+=("in-sync: generated manifest is not valid JSON")
	grep -qF 'docs/template-repo-banner.png' "$root/out.txt" \
		|| reasons+=("in-sync: cleaned_files missing the banner entry")

	# Recipe removes a path the list never got: fail with a per-path report
	sb=$(new_guard_sandbox removed_not_listed)
	printf '\n    rm -f ".just/lib/phantom_test.sh"\n' >>"$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 1 "removed-not-listed: drift must fail generation"
	expect_err 'removed by clean_template but not listed in CLEANED_FILES: .just/lib/phantom_test.sh' \
		"removed-not-listed: missing per-path report"

	# Typo'd list entry: both directions in one report (the typo as
	# listed-but-not-removed, the real path as removed-but-not-listed)
	sb=$(new_guard_sandbox listed_not_removed)
	sed -i.tmp 's/compliance_test\.sh/complance_test.sh/' "$sb/.just/lib/generate_checksums.sh"
	rm -f "$sb/.just/lib/generate_checksums.sh.tmp"
	run_guard "$sb"
	expect_rc 1 "listed-not-removed: drift must fail generation"
	expect_err 'listed in CLEANED_FILES but not removed by clean_template: .just/lib/complance_test.sh' \
		"listed-not-removed: missing the typo'd entry report"
	expect_err 'removed by clean_template but not listed in CLEANED_FILES: .just/lib/compliance_test.sh' \
		"listed-not-removed: missing the real path report"

	# A column-0 comment example must not poison the scan (the NOTE
	# documenting the form nearly did, review of #438)
	sb=$(new_guard_sandbox comment_poison)
	printf '# keep the rm -f "literal path" form (rm -rf likewise)\n' >>"$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 0 "comment-poison: a column-0 example must not count as a removal"
	expect_err_empty "comment-poison"

	# No extractable rm lines at all: pointed stale-pattern error, not a
	# vacuous pass and not a wall of mismatches
	sb=$(new_guard_sandbox zero_extraction)
	printf 'clean_template:\n    rm -f .just/unquoted.just\n' >"$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 1 "zero-extraction: must fail, not pass vacuously"
	expect_err 'the drift guard extracted no rm paths' "zero-extraction: missing the pointed error"
	expect_err 'stale extraction pattern' "zero-extraction: missing the stale-pattern hint"

	# Missing recipe (derived repos): warn and skip, generation still passes
	sb=$(new_guard_sandbox missing_recipe)
	rm "$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 0 "missing-recipe: generation must proceed"
	expect_err 'skipping CLEANED_FILES drift check' "missing-recipe: missing the skip warning"

	# Double-quoted variable rm: surfaces as its literal text, not lost
	sb=$(new_guard_sandbox variable_rm)
	# shellcheck disable=SC2016  # $SOME_VAR must reach the recipe literally
	printf '\n    rm -f "$SOME_VAR"\n' >>"$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 1 "variable-rm: extraction must flag it, not lose it"
	# shellcheck disable=SC2016  # matching the literal $SOME_VAR text
	expect_err 'removed by clean_template but not listed in CLEANED_FILES: $SOME_VAR' \
		"variable-rm: \$SOME_VAR not reported"

	# Quoted scratch files stay excluded by name: the exclusion currently
	# matches nothing in the real recipe (both scratch removals are
	# unquoted), so this case is what keeps it live defense-in-depth
	sb=$(new_guard_sandbox scratch_tmp)
	printf '\n    rm -f "justfile.tmp"\n    rm -f ".repo.toml.tmp"\n' >>"$sb/.just/clean-template.just"
	run_guard "$sb"
	expect_rc 0 "scratch-tmp: quoted scratch files must stay excluded"
	expect_err_empty "scratch-tmp"

	# Version-drift guard red paths (Claude review of #442, item 2):
	# a '# PR create' header disagreeing with the newest notes entry
	# must fail generation with a pointed report; a derived-repo
	# sandbox without RELEASE_NOTES.md must skip silently (the skip is
	# by design - the notes file is not CHECKSUMS-tracked); and an
	# unparseable pair warns without blocking, so a future format
	# change degrades loudly, not fatally
	sb=$(new_guard_sandbox version_drift)
	sed -i.tmp -E 's/^# PR create v[0-9.]+/# PR create v0.1/' "$sb/.just/gh-process.just"
	rm -f "$sb/.just/gh-process.just.tmp"
	run_guard "$sb"
	expect_rc 1 "version-drift: header/notes mismatch must fail generation"
	expect_err 'but the newest RELEASE_NOTES.md entry is' \
		"version-drift: missing the mismatch report"

	sb=$(new_guard_sandbox version_missing_notes)
	rm "$sb/.just/RELEASE_NOTES.md"
	run_guard "$sb"
	expect_rc 0 "version-missing-notes: derived-repo shape must generate"
	expect_err_empty "version-missing-notes"

	sb=$(new_guard_sandbox version_unparseable)
	printf '# no version header here\n' >"$sb/.just/gh-process.just"
	run_guard "$sb"
	expect_rc 0 "version-unparseable: warn, do not block"
	expect_err 'skipping version drift check' "version-unparseable: missing the skip warning"

	rm -rf "$root"

	if [[ ${#reasons[@]} -eq 0 ]]; then
		echo -e "${GREEN}✓${NORMAL} guard_selftest"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} guard_selftest"
		local reason
		for reason in "${reasons[@]}"; do
			echo "    $reason"
		done
		(( failed += 1 ))
	fi
}

# semver_selftest: pin the #436 release comparator beyond fixture reach.
# The release fixtures exercise only a few comparator branches
# (confirm, decline, stable-after-rc, equal +build, short form), so
# the rest - the full semver.org #11 precedence chain, numeric vs
# alphanumeric identifiers, leading-zero octal traps, 2^63 overflow
# traps, identifier counts, degenerate tags - is pinned here,
# table-driven, against functions extracted LIVE from the release
# recipe (the same drift-fails-the-suite contract as guard_selftest
# and the compliance pattern extraction). A moved or reworded marker
# comment breaks the extraction, and that break is the feature - it
# is how drift gets caught (Claude review of #439, item 1).
semver_selftest() {
	local reasons=()
	local root extracted driver battery_err rc

	root=$(mktemp -d)
	extracted="$root/semver_extracted.sh"
	driver="$root/battery.sh"
	battery_err="$root/battery_err.txt"

	# Extract the comparator functions live: from the semver_parse
	# marker comment to the order-check marker that follows it, the
	# 4-space recipe indent stripped. An extraction without both
	# functions is a stale marker, not a vacuous pass - fail loudly
	# (the same trap the drift guard documents, review of #438).
	sed -n '/^    # semver_parse TAG:/,/^    # Monotonic version-order check/p' \
		"$SCRIPT_DIR/../gh-process.just" | sed '$d; s/^    //' >"$extracted"
	if ! grep -q '^semver_parse()' "$extracted" || ! grep -q '^semver_compare()' "$extracted"; then
		echo -e "${RED}✗${NORMAL} semver_selftest"
		echo "    extraction found no comparator functions in gh-process.just - suspect a moved/reworded marker comment"
		(( failed += 1 ))
		rm -rf "$root"
		return 0
	fi

	# Battery rows: want|A|B means semver_compare A B must print want;
	# rc2|A| means A must fail to parse (rc=2) against v1.0.0. Version
	# grammar admits no pipes, so the separator is unambiguous.
	local -a rows=(
		"-1|v0.9.0|v1.0.0"
		"1|v1.0|v0.9.0"
		"1|v1|v0.9.9"
		"-1|v1|v1.0.1"
		"1|v1.2.1|v1.2"
		"0|v1.2|v1.2.0"
		"0|v1.0.0|v1.0.0"
		"0|v1.0.0+build.1|v1.0.0+build.2"
		"0|v1.0.0|v1.0.0+build.9"
		"-1|v1.0.0-rc1+b2|v1.0.0"
		"1|v1.0.0+xyz|v1.0.0-rc1"
		"-1|v1.0.0-1|v1.0.0-alpha"
		"1|v1.0.0-alpha|v1.0.0-1"
		"-1|v1.0.0-2|v1.0.0-10"
		"1|v1.0.0-10|v1.0.0-2"
		"-1|v1.007|v1.10"
		"1|v1.10|v1.007"
		"-1|v1.0.0-007|v1.0.0-10"
		"1|v99999999999999999999|v1"
		"-1|v1|v99999999999999999999"
		"1|v1.0.0-99999999999999999999|v1.0.0-9"
		"-1|v1.0.0-9|v1.0.0-99999999999999999999"
		"0|v00000000000000000001|v1"
		"1|v1.0.0-rc.1|v1.0.0-rc"
		"-1|v1.0.0-rc|v1.0.0-rc.1"
		"-1|v1.0.0-alpha|v1.0.0-beta"
		"1|v1.0.0-beta|v1.0.0-alpha"
		"1|v1.0.0|v1.0.0--"
		"-1|v1.0.0--|v1.0.0"
		"0|v1.0.0-|v1.0.0"
		"1|2026-11-02|v1.0.0"
		"-1|2026-10-02|2026-11-02"
		"rc2|legacy-2024-tag|"
		"rc2|v1.2.3.4|"
		"rc2||"
		"rc2|v1.0.0-rc..1|"
		"rc2|v1.0.0-rc.|"
		"rc2|v1.0.0-.rc|"
		"rc2|v1.2.|"
		"rc2|.1.2|"
		"rc2|v1..2|"
	)

	# Build the driver: one bash process sources the extracted
	# comparator and walks the rows plus the semver.org #11 chain.
	# Every miss prints one FAIL line to stderr; the exit code is the
	# miss count, so the verdict survives set -euo pipefail. The
	# emitted lines are single-quoted on purpose - the driver must
	# receive literal bash, not the harness's expansion (SC2016 is
	# the point here, same as the awk script in match_expected_output).
	{
		echo '#!/usr/bin/env bash'
		echo 'set -euo pipefail'
		echo "source '$extracted'"
		echo 'fails=0'
		echo 'expect() {'
		echo '    local got rc=0'
		echo '    got=$(semver_compare "$2" "$3") || rc=$?'
		echo '    if [[ "$rc" -ne 0 ]]; then'
		echo '        echo "FAIL parse($2, $3): rc=$rc, wanted a compare" >&2'
		echo '        fails=$((fails + 1))'
		echo '        return'
		echo '    fi'
		echo '    if [[ "$got" != "$1" ]]; then'
		echo '        echo "FAIL cmp($2, $3): want $1, got $got" >&2'
		echo '        fails=$((fails + 1))'
		echo '    fi'
		echo '}'
		echo 'expect_parse_fail() {'
		echo '    local got rc=0'
		echo '    got=$(semver_compare "$1" v1.0.0) || rc=$?'
		echo '    if [[ "$rc" -ne 2 ]]; then'
		echo '        echo "FAIL parse($1): want rc=2, got rc=$rc ($got)" >&2'
		echo '        fails=$((fails + 1))'
		echo '    fi'
		echo '}'
		local row want rest a b
		for row in "${rows[@]}"; do
			want="${row%%|*}"
			rest="${row#*|}"
			a="${rest%%|*}"
			b="${rest#*|}"
			if [[ "$want" == "rc2" ]]; then
				printf 'expect_parse_fail %q\n' "$a"
			else
				printf 'expect %q %q %q\n' "$want" "$a" "$b"
			fi
		done
		echo 'chain=(v1.0.0-alpha v1.0.0-alpha.1 v1.0.0-alpha.beta v1.0.0-beta v1.0.0-beta.2 v1.0.0-beta.11 v1.0.0-rc.1 v1.0.0)'
		echo 'i=0'
		echo 'while (( i < ${#chain[@]} - 1 )); do'
		echo '    expect -1 "${chain[$i]}" "${chain[$((i + 1))]}"'
		echo '    expect 1  "${chain[$((i + 1))]}" "${chain[$i]}"'
		echo '    i=$((i + 1))'
		echo 'done'
		echo 'exit $fails'
	} >"$driver"

	rc=0
	bash "$driver" >/dev/null 2>"$battery_err" || rc=$?
	if [[ "$rc" -ne 0 ]]; then
		local line
		while IFS= read -r line || [[ -n "$line" ]]; do
			[[ -n "$line" ]] && reasons+=("$line")
		done <"$battery_err"
	fi

	rm -rf "$root"

	if [[ ${#reasons[@]} -eq 0 ]]; then
		echo -e "${GREEN}✓${NORMAL} semver_selftest"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} semver_selftest"
		local reason
		for reason in "${reasons[@]}"; do
			echo "    $reason"
		done
		(( failed += 1 ))
	fi
}

# Recipe mode: run the real `just <recipe> <args...>` inside a temp
# workspace that mirrors a derived repo (minimal justfile importing a
# copy of the real template-sync.just + common.sh), with mocked curl
# serving the fixture manifest/template versions.
run_recipe_test() {
	local test_name="$1"
	local test_dir="$2"

	if ! command -v just &>/dev/null; then
		echo -e "${YELLOW}!${NORMAL} $test_name - just not installed, recipe gate untested"
		(( failed += 1 ))
		return
	fi

	# Create temp workspace
	local workspace
	workspace=$(mktemp -d)

	# Copy input files to workspace (including hidden files)
	if [[ -d "$test_dir/input" ]]; then
		shopt -s dotglob
		cp -r "$test_dir/input/"* "$workspace/" 2>/dev/null || true
		shopt -u dotglob
	fi

	# Scaffold a minimal derived-repo justfile importing the real modules.
	# Fixture `modules` picks which (default: template-sync); fixture
	# `bare_justfile` drops the `set positional-arguments` line so the
	# workspace mirrors a derived repo's justfile exactly (#367/#368)
	local module_list="template-sync"
	if [[ -f "$test_dir/modules" ]]; then
		if [[ ! -s "$test_dir/modules" ]]; then
			echo -e "${RED}✗${NORMAL} $test_name - modules file is empty"
			rm -rf "$workspace"
			(( failed += 1 ))
			return
		fi
		module_list=$(cat "$test_dir/modules")
	fi
	mkdir -p "$workspace/.just/lib"
	local module
	for module in $module_list; do
		if [[ ! -f "$SCRIPT_DIR/../$module.just" ]]; then
			echo -e "${RED}✗${NORMAL} $test_name - unknown module: $module"
			rm -rf "$workspace"
			(( failed += 1 ))
			return
		fi
		cp "$SCRIPT_DIR/../$module.just" "$workspace/.just/"
	done
	cp "$SCRIPT_DIR/common.sh" "$workspace/.just/lib/"
	{
		if [[ ! -f "$test_dir/bare_justfile" ]]; then
			echo "set positional-arguments := true"
		fi
		for module in $module_list; do
			echo "import '.just/$module.just'"
		done
	} > "$workspace/justfile"

	# Mock curl serving fixture data (shared contract - see write_mock_curl)
	write_mock_curl "$workspace"

	# Fixture shims: copied in executable and prepended to PATH below,
	# ahead of the harness mock curl (whole-workspace dir first on PATH)
	if [[ -d "$test_dir/shims" ]]; then
		local shim
		for shim in "$test_dir"/shims/*; do
			[[ -f "$shim" ]] || continue
			cp "$shim" "$workspace/"
			chmod +x "$workspace/$(basename "$shim")"
		done
	fi

	# Copy manifest + template versions (curl mock resolves these)
	[[ -f "$test_dir/manifest.json" ]] && cp "$test_dir/manifest.json" "$workspace/"
	if [[ -d "$test_dir/template_versions" ]]; then
		mkdir -p "$workspace/template_versions"
		cp -r "$test_dir/template_versions/"* "$workspace/template_versions/" 2>/dev/null || true
	fi

	# Parse the recipe line: first word = recipe name, rest = arguments.
	# Guard against an empty recipe file under set -u.
	local recipe_name recipe_line=()
	if [[ ! -s "$test_dir/recipe" ]]; then
		echo -e "${RED}✗${NORMAL} $test_name - recipe file is empty"
		rm -rf "$workspace"
		(( failed += 1 ))
		return
	fi
	read -r -a recipe_line <<< "$(cat "$test_dir/recipe")"
	recipe_name="${recipe_line[0]}"
	local recipe_args=("${recipe_line[@]:1}")

	# Run the recipe with the workspace first on PATH (fixture shims
	# shadow both the harness mock curl and real tools). The if/else
	# branch keeps empty-argument recipes working under set -u on bash
	# 3.2 (macOS), where "empty_array[@]" is an unbound-variable error.
	# stdin comes from the fixture's `stdin` file when present, else
	# /dev/null, so interactive prompts (copilot_rollback's selection
	# read, #382) get deterministic input and a run can never hang on a
	# TTY; recipes that never read stdin are unaffected by EOF.
	cd "$workspace"
	local output actual_exit=0
	local stdin_file="/dev/null"
	[[ -f "$test_dir/stdin" ]] && stdin_file="$test_dir/stdin"
	if [[ ${#recipe_args[@]} -gt 0 ]]; then
		output=$(PATH="$workspace:$PATH" just "$recipe_name" "${recipe_args[@]}" < "$stdin_file" 2>&1) \
			|| actual_exit=$?
	else
		output=$(PATH="$workspace:$PATH" just "$recipe_name" < "$stdin_file" 2>&1) \
			|| actual_exit=$?
	fi

	# Expected exit code (default 0)
	local expected_exit=0
	if [[ -f "$test_dir/expected_exit" ]]; then
		expected_exit=$(cat "$test_dir/expected_exit")
	fi

	# Check expected output and state through the shared helpers, so
	# the two runner modes cannot drift (#376/#377)
	match_expected_output "$output" "$test_dir" "$test_name"
	verify_expected_state "$workspace" "$test_dir"

	# Cleanup
	cd - >/dev/null
	rm -rf "$workspace"

	# Report result
	local exit_ok=true
	[[ "$actual_exit" == "$expected_exit" ]] || exit_ok=false

	if [[ "$exit_ok" == true && "$output_ok" == true && "$state_ok" == true ]]; then
		echo -e "${GREEN}✓${NORMAL} $test_name"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} $test_name"
		[[ "$exit_ok" == false ]] && echo "    Exit mismatch: expected $expected_exit, got $actual_exit"
		[[ "$output_ok" == false ]] && { echo "    Output mismatch:"; echo "$output_mismatch"; }
		[[ "$state_ok" == false ]] && echo "    State mismatch: $state_mismatch"
		(( failed += 1 ))
	fi
}

# Update-script mode (legacy): drive a patched copy of template_update.sh
run_update_test() {
	local test_name="$1"
	local test_dir="$2"

	# Create temp workspace
	local workspace
	workspace=$(mktemp -d)

	# Copy input files to workspace (including hidden files)
	if [[ -d "$test_dir/input" ]]; then
		shopt -s dotglob
		cp -r "$test_dir/input/"* "$workspace/" 2>/dev/null || true
		shopt -u dotglob
	fi

	# Mock curl to return fixture data (shared contract - see write_mock_curl)
	write_mock_curl "$workspace"

	# Copy manifest to workspace
	if [[ -f "$test_dir/manifest.json" ]]; then
		cp "$test_dir/manifest.json" "$workspace/"
	fi

	# Copy template versions if they exist
	if [[ -d "$test_dir/template_versions" ]]; then
		mkdir -p "$workspace/template_versions"
		cp -r "$test_dir/template_versions/"* "$workspace/template_versions/" 2>/dev/null || true
	fi

	# Run update logic with mocked curl
	cd "$workspace"
	export PATH="$workspace:$PATH"

	# Copy common.sh to workspace so sourcing works
	cp "$SCRIPT_DIR/common.sh" "$workspace/"

	# Create a modified version of template_update.sh that uses our workspace
	local test_script="$workspace/test_update.sh"
	# Escape pipe characters in workspace path to prevent sed command breaking
	local escaped_workspace="${workspace//|/\\|}"
	sed 's|readonly MANIFEST_FILE=\$(mktemp)|readonly MANIFEST_FILE="'"$escaped_workspace"'/manifest.json"|g' \
		"$SCRIPT_DIR/template_update.sh" > "$test_script"
	chmod +x "$test_script"

	# Capture output
	local output
	output=$("$test_script" 2>&1 || true)

	# Check expected output and state through the shared helpers, so
	# the two runner modes cannot drift (#376/#377)
	match_expected_output "$output" "$test_dir" "$test_name"
	verify_expected_state "$workspace" "$test_dir"

	# Cleanup
	cd - >/dev/null
	rm -rf "$workspace"

	# Report result
	if [[ "$output_ok" == true && "$state_ok" == true ]]; then
		echo -e "${GREEN}✓${NORMAL} $test_name"
		(( passed += 1 ))
	else
		echo -e "${RED}✗${NORMAL} $test_name"
		[[ "$output_ok" == false ]] && { echo "    Output mismatch:"; echo "$output_mismatch"; }
		[[ "$state_ok" == false ]] && echo "    State mismatch: $state_mismatch"
		(( failed += 1 ))
	fi
}

# Main execution
main() {
	echo -e "${BLUE}Running template sync tests...${NORMAL}"
	echo

	# Check if fixtures directory exists
	if [[ ! -d "$FIXTURES_DIR" ]]; then
		echo -e "${YELLOW}No test fixtures found at $FIXTURES_DIR${NORMAL}"
		echo "Tests skipped"
		return 0
	fi

	# Self-test the matcher/state helpers before the fixture pass: the
	# mismatch diagnostics only print on failure, and no fixture is
	# supposed to fail, so the dump and state-reason paths need their
	# own coverage (review round, #433)
	harness_selftest

	# Assert the common.sh security boundary before the fixture pass:
	# validate_filepath / sanitize_for_display are the sync system's
	# actual gate (#347), and no fixture pins their rejection classes
	# individually (#382)
	security_boundary_selftest

	# Drive the CLEANED_FILES drift guard's failure modes through the
	# real generate_checksums.sh in scratch sandboxes: the guard's red
	# paths fire only when a bump PR is mid-drift, so without this a
	# regressed extraction pattern would sail through every green run
	# (review of #438, #381)
	guard_selftest

	# Pin the #436 release comparator's precedence rules beyond fixture
	# reach: the release fixtures drive only a few compare branches,
	# so the semver.org #11 chain and the degenerate-tag parse failures
	# live here, against functions extracted live from the recipe
	# (Claude review of #439, item 1)
	semver_selftest

	# Run each test
	for test_dir in "$FIXTURES_DIR"/*; do
		if [[ -d "$test_dir" ]]; then
			test_name=$(basename "$test_dir")
			run_test "$test_name"
		fi
	done

	# Summary
	echo
	echo "Results: ${GREEN}$passed passed${NORMAL}, ${RED}$failed failed${NORMAL}"

	if [[ $failed -gt 0 ]]; then
		exit 1
	fi
}

main "$@"
