# project justfile

# github process recipes carried over from the template repo
import? '.just/gh-process.just'

# we could split this justfile up more but I wanted to keep the
# most interesting parts of the demo in this file.

# list / default
[group('just')]
list:
	just --list

# preview DNS changes
[group('dnscontrol')]
preview:
	cd dns && dnscontrol preview --cmode concurrent

# push into results directory, someday production
[group('dnscontrol')]
push:
	cd dns && dnscontrol push --cmode concurrent

# install prerequisites (on Macs)
[macos, group('install')]
install_prereqs:
	brew install jq dnscontrol coredns
	# some rust magic to get cargo that I've forgotten
	cargo install toml-cli

latest_release := `gh release list -L 1 --json name,isLatest | jq -r '.[].name'`
container_name := "fini-coredns-dnscontrol-example"

# build container with podman
[group('container')]
build_con:
	@echo "{{BLUE}}latest_release={{ latest_release }}{{NORMAL}}"
	# just makes sure that . is the topmost dir of the git repo
	podman build -t {{ container_name }}:latest -t {{ container_name}}:{{ latest_release }} --build-arg BUILD_VERSION="{{ latest_release }}" .

# run container with podman
[group('container')]
run_con:
	#podman run -d --name corednstest -p 1029:53/udp {{ container_name }} --conf /root/Corefile
	podman run -d --name corednstest -p 1029:53/udp {{ container_name }} --conf /etc/Corefile

# clean up containers with podman
[group('container')]
clean_con:
	podman stop corednstest
	podman rm corednstest
