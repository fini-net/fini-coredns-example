# FINI coredns example

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11155/badge)](https://www.bestpractices.dev/projects/11155)
![GitHub Issues](https://img.shields.io/github/issues/fini-net/fini-coredns-example)
![GitHub Pull Requests](https://img.shields.io/github/issues-pr/fini-net/fini-coredns-example)
![GitHub License](https://img.shields.io/github/license/fini-net/fini-coredns-example)
![GitHub watchers](https://img.shields.io/github/watchers/fini-net/fini-coredns-example)

A complete example demonstrating how to use
[DNSControl](https://github.com/StackExchange/dnscontrol) to generate DNS zone
files and serve them with [CoreDNS](https://coredns.io/) in a container.

## What's Included

This repository provides:

- **JavaScript DNS Configuration**: Define DNS records using DNSControl's
  JavaScript syntax for `example.com` and `example.org` domains
- **Automated Zone File Generation**: Convert JavaScript configurations to BIND
  zone files with `just push`
- **Containerized DNS Server**: Ready-to-run CoreDNS container serving the generated zones
- **Automated Testing**: Go test suite validating DNS responses for 10+ specific records
- **Development Workflow**: Complete `just` command recipes for building, testing, and deploying
- **GitHub Container Registry**: Pre-built container images available at
  `ghcr.io/fini-net/fini-coredns-example`

## Quick Start

1. **Generate zone files**: `just push` (uses DNSControl to create BIND files from JavaScript)
2. **Build container**: `just build_con` (creates local container with CoreDNS + zone files)
3. **Start DNS server**: `just run_con` (runs container on port 1029)
4. **Test functionality**: `just test_dns` (validates DNS responses) or `dig
   @localhost -p 1029 www.example.com`

The [development process](.github/CONTRIBUTING.md#development-process)
documents all available `just` subcommands for working with this repository.

### Working with the container

To generate the container on your local machine run `just build_con`.

To run the built container run `just run_con`.  A DNS server should be
available on port 1029.  You can see it working with `dig` like so:

```ShellSession
% dig @localhost -p 1029 www.example.com

; <<>> DiG 9.10.6 <<>> @localhost -p 1029 www.example.com
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 3344
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 4, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.example.com.               IN      A

;; ANSWER SECTION:
www.example.com.        3600    IN      CNAME   server1.example.com.
server1.example.com.    3600    IN      A       10.0.0.101

;; AUTHORITY SECTION:
example.com.            3600    IN      NS      ns0.example.com.
example.com.            3600    IN      NS      ns1.example.com.
example.com.            3600    IN      NS      ns2.example.com.
example.com.            3600    IN      NS      ns3.example.com.

;; Query time: 6 msec
;; SERVER: ::1#1029(::1)
;; WHEN: Sat Jul 05 20:26:48 PDT 2025
;; MSG SIZE  rcvd: 287
```

That is the same CNAME and IP that you can see in the
[zone file](dns/zones/example.com.zone).

#### Easier working wih the container

To save you some typing you could run `just test_con` to get this
experience:

```ShellSession
% just test_con
Expect to see in dig output:
;; ANSWER SECTION:
www.example.com.        3600    IN      CNAME   server1.example.com.
server1.example.com.    3600    IN      A       10.0.0.101

dig @localhost -p 1029 www.example.com

; <<>> DiG 9.10.6 <<>> @localhost -p 1029 www.example.com
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 36425
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 4, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.example.com.               IN      A

;; ANSWER SECTION:
www.example.com.        3600    IN      CNAME   server1.example.com.
server1.example.com.    3600    IN      A       10.0.0.101

;; AUTHORITY SECTION:
example.com.            3600    IN      NS      ns0.example.com.
example.com.            3600    IN      NS      ns1.example.com.
example.com.            3600    IN      NS      ns2.example.com.
example.com.            3600    IN      NS      ns3.example.com.

;; Query time: 2 msec
;; SERVER: ::1#1029(::1)
;; WHEN: Thu Jul 10 12:37:44 PDT 2025
;; MSG SIZE  rcvd: 287
```

Looks great until we can automate it!™

#### Container commands reference

For direct podman usage without `just`:

```bash
# Run the container (DNS server on port 1029)
podman run -d --name corednstest -p 1029:53/udp ghcr.io/fini-net/fini-coredns-example --config /etc/Corefile

# Test the DNS server
dig @localhost -p 1029 www.example.com

# Stop and clean up
podman stop corednstest
podman rm corednstest

# Inspect container metadata
podman inspect fini-coredns-example | jq '.[0].Labels'
```

## Testing

The repository includes automated Go tests that validate DNS responses from the container:

```ShellSession
% just test_dns
Make sure container is running: just run_con
=== RUN   TestDNSRecords
=== RUN   TestDNSRecords/example.com_root_A_record
=== RUN   TestDNSRecords/server1.example.com_A_record
=== RUN   TestDNSRecords/ns0.example.com_A_record
=== RUN   TestDNSRecords/www.example.com_CNAME_record
=== RUN   TestDNSRecords/ftp.example.com_CNAME_record
=== RUN   TestDNSRecords/server1.example.com_AAAA_record
=== RUN   TestDNSRecords/server1.example.com_TXT_record
=== RUN   TestDNSRecords/example.org_root_A_record
=== RUN   TestDNSRecords/www.example.org_A_record
=== RUN   TestDNSRecords/calendar.example.org_CNAME_record
--- PASS: TestDNSRecords (0.01s)
    --- PASS: TestDNSRecords/example.com_root_A_record (0.00s)
    --- PASS: TestDNSRecords/server1.example.com_A_record (0.00s)
    --- PASS: TestDNSRecords/ns0.example.com_A_record (0.00s)
    --- PASS: TestDNSRecords/www.example.com_CNAME_record (0.00s)
    --- PASS: TestDNSRecords/ftp.example.com_CNAME_record (0.00s)
    --- PASS: TestDNSRecords/server1.example.com_AAAA_record (0.00s)
    --- PASS: TestDNSRecords/server1.example.com_TXT_record (0.00s)
    --- PASS: TestDNSRecords/example.org_root_A_record (0.00s)
    --- PASS: TestDNSRecords/www.example.org_A_record (0.00s)
    --- PASS: TestDNSRecords/calendar.example.org_CNAME_record (0.00s)
=== RUN   TestContainerHealthCheck
--- PASS: TestContainerHealthCheck (0.00s)
=== RUN   TestNSRecords
--- PASS: TestNSRecords (0.00s)
=== RUN   TestMXRecords
=== RUN   TestMXRecords/example.com
=== RUN   TestMXRecords/example.org
--- PASS: TestMXRecords (0.00s)
    --- PASS: TestMXRecords/example.com (0.00s)
    --- PASS: TestMXRecords/example.org (0.00s)
PASS
ok  	github.com/fini-net/fini-coredns-example/test	0.220s
```

The test suite validates specific DNS records including A, AAAA, CNAME, TXT, NS, and MX records across both example domains. Tests require the container to be running first via `just run_con`.

## Standards

The domains and IPs in the examples contained in this repo should comply with

- [RFC2606: Reserved Top Level DNS Names](https://www.rfc-editor.org/rfc/rfc2606.html)
- [RFC1918: Address Allocation for Private Internets](https://www.rfc-editor.org/rfc/rfc1918.html)
- [RFC4193: Unique Local IPv6 Unicast Addresses](https://www.rfc-editor.org/rfc/rfc4193.txt)

to avoid interfering with any existing infrastructure.

## Contributing

- [Code of Conduct](.github/CODE_OF_CONDUCT.md)
- [Contributing Guide](.github/CONTRIBUTING.md) includes a step-by-step guide to our
  [development processs](.github/CONTRIBUTING.md#development-process).

## Support & Security

- [Getting Support](.github/SUPPORT.md)
- [Security Policy](.github/SECURITY.md)

## Thanks

- Robb Manes wrote
  [Running CoreDNS as a DNS Server in a Container](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
  which walks you how to do something similar for yourself.
- This [ServerFault answer](https://serverfault.com/a/216611/205542) helped me find RFC4193
  for the safe IPv6 address range.
- [networkupstools](https://github.com/networkupstools/nut/wiki/Building-NUT-integration-for-Home-Assistant)
  shows how to set a lot of metadata during your container build.
- Kudos to Jason Hall for [documenting the nice way to login to ghcr](https://github.com/cli/cli/pull/8558),
  but it doesn't work (yet?) so I had to create a PAT after all.
