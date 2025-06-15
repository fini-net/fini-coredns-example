# project justfile

# some useful variables
host := `uname -n`
release_branch := "main"

# thanks to https://stackoverflow.com/a/7293026/2002471 for the perfect git incantation
last_commit_message := `git log -1 --pretty=%B | grep '.'`

# list recipes (default works without naming it)
[group('example')]
list:
	just --list
	@echo "{{GREEN}}Your justfile is waiting for more scripts and snippets{{NORMAL}}"

# escape from branch, back to starting point
[group('Process')]
sync:
    git checkout {{ release_branch }}
    git pull
    git stp

# PR create 3.0
[group('Process')]
pr: _on_a_branch
    #!/usr/bin/env bash
    set -euxo pipefail # strict mode

    git stp
    git pushup

    set +x # leave tracing off...

    bodyfile=$(mktemp /tmp/justfile.XXXXXX)

    echo "## Done:" >> $bodyfile
    echo "" >> $bodyfile
    echo "- {{ last_commit_message }}" >> $bodyfile
    echo "" >> $bodyfile
    echo "" >> $bodyfile
    echo "(Automated in \`justfile\`.)" >> $bodyfile

    echo ''
    cat "$bodyfile"
    echo ''

    gh pr create --title "{{ last_commit_message }}" --body-file "$bodyfile"
    rm "$bodyfile"

    if [[ ! -e ".github/workflows" ]]; then
        echo "{{BLUE}}there are no workflows in this repo so there are no PR checks to watch{{NORMAL}}"
        exit 0
    fi

    echo "{{BLUE}}sleeping for 10s because github is lazy with their API{{NORMAL}}"
    sleep 10
    gh pr checks --watch

# merge PR and return to starting point
[group('Process')]
merge: _on_a_branch
    gh pr merge -s -d
    just sync # mostly redundant, but just in case

# start a new branch
[group('Process')]
branch branchname: _main_branch
    #!/usr/bin/env bash
    NOW=`just utcdate`
    git co -b "chicks/$NOW-{{ branchname }}"

# view PR in web browser
[group('Process')]
prweb: _on_a_branch
    gh pr view --web

# error if not on a git branch
[group('sanity check')]
[no-cd]
_on_a_branch:
    #!/bin/bash

    # thanks to https://stackoverflow.com/a/12142066/2002471

    if [[ $(git rev-parse --abbrev-ref HEAD) == "{{ release_branch }}" ]]; then
      echo "{{RED}}You are on branch '{{ release_branch }}' (the release branch) so you are not ready to start a PR.{{NORMAL}}"
      exit 100
    fi

# error if not on the release branch
[group('sanity check')]
[no-cd]
_main_branch:
    #!/bin/bash

    # thanks to https://stackoverflow.com/a/12142066/2002471

    if [[ ! $(git rev-parse --abbrev-ref HEAD) == "{{ release_branch }}" ]]; then
      echo "You are on a branch that is not the release branch so you are not ready to start a new branch."
      exit 100
    fi

# print UTC date in ISO format
[group('Utility')]
[no-cd]
@utcdate:
    TZ=UTC date +"%Y-%m-%d"

# make a release
[group('Process')]
release rel_version:
   gh release create {{rel_version}} --generate-notes

# preview
[group('dnscontrol')]
[no-cd]
preview:
        dnscontrol preview

# push into results directory, someday production
[group('dnscontrol')]
[no-cd]
push:
        dnscontrol push --cmode concurrent

# should not be needed anymore, keeping as example
[group('dnscontrol')]
[no-cd]
domain_group_import group:
        dnscontrol get-zones --format=js --out={{group}}.js bind - `just domains_in_group {{group}}`

#
# install software recipes
#

[macos, group('install')]
install_prereqs:
	brew install jq dnscontrol coredns
	# some rust magic to get cargo that I've forgotten
	cargo install toml-cli
