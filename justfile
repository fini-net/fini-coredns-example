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

# container build/push variables
latest_release := `gh release list -L 1 --json name,isLatest | jq -r '.[].name'`
repo_name := "fini-coredns-example"
container_repo := "ghcr.io"
github_user := "fini-net"

# build container with podman
[group('container')]
build_con:
	@echo "{{BLUE}}latest_release={{ latest_release }}{{NORMAL}}"
	# just makes sure that . is the topmost dir of the git repo
	podman build -t {{ repo_name }}:latest -t {{ repo_name}}:{{ latest_release }} -t {{ container_repo }}/{{ github_user }}/{{ repo_name }}:latest -t {{ container_repo }}/{{ github_user }}/{{ repo_name }}:{{ latest_release }} --build-arg BUILD_VERSION="{{ latest_release }}" .

# run container with podman
[group('container')]
run_con:
	podman run -d --name corednstest -p 1029:53/udp {{ repo_name }} --conf /etc/Corefile

# clean up containers with podman
[group('container')]
clean_con:
	podman stop corednstest
	podman rm corednstest

# test containerized coredns with dig
[group('container')]
test_con:
	@echo "{{BLUE}}Expect to see in dig output:\n;; ANSWER SECTION:\nwww.example.com.        3600    IN      CNAME   server1.example.com.\nserver1.example.com.    3600    IN      A       10.0.0.101{{NORMAL}}\n"
	dig @localhost -p 1029 www.example.com

# inspect containerized coredns
[group('container')]
inspect_con:
	podman inspect fini-coredns-example | jq '.[0].Labels'

# TODO: redo this to work with the PAT
# login to ghcr
#[group('container')]
#ghcr_login:
#	#!/usr/bin/env bash
#
#	if podman login {{ container_repo }} --get-login > /dev/null; then
#		echo "{{GREEN}}already logged in to {{ container_repo }}.{{NORMAL}}"
#	else
#		gh auth token | podman login {{ container_repo }} --username {{ github_user }} --password-stdin
#	fi

# login to ghcr
[group('container')]
ghcr_logout:
	podman logout {{ container_repo }}

# push container to ghcr
[group('container')]
ghcr_push:
	podman login {{ container_repo }} --get-login # check current user and fail if not logged in
	podman push {{ container_repo }}/{{ github_user }}/{{ repo_name }}:{{ latest_release }}
	podman push {{ container_repo }}/{{ github_user }}/{{ repo_name }}:latest

# ?? should we use the two argument form of `push` instead?
# ?? should we only push each build once?
