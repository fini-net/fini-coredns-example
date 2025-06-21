# project justfile

import? '.just/gh-process.just'

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

# install prerequisites (on Macs)
[macos, group('install')]
install_prereqs:
	brew install jq dnscontrol coredns
	# some rust magic to get cargo that I've forgotten
	cargo install toml-cli
