# CoreDNS Ideas Discussion: DNSControl + CoreDNS Example Repository

Posted at: <https://github.com/coredns/coredns/discussions/7907>

Subject: Example repo: DNSControl → CoreDNS container with automated Go tests

---

Hey CoreDNS community!

I've been using CoreDNS for a while now and kept running into the same
question from folks getting started: "OK, I've got zone files — now
how do I actually wire this into a container and test it properly?"

So I built a complete example repository that walks through the whole
thing, end to end:

**Repository**: <https://github.com/fini-net/fini-coredns-example>

## What it demonstrates

The core idea is using [DNSControl](https://github.com/StackExchange/dnscontrol)
to define DNS records in JavaScript, generating standard BIND zone files,
and then having CoreDNS serve those zones from a container. Here's the
full stack:

- **DNSControl JavaScript configs** → `dnscontrol push` → **BIND zone files**
- **BIND zone files** → copied into a CoreDNS container image
- **CoreDNS** serves the zones via the `file` plugin (straightforward
  Corefile, nothing exotic)
- **Go test suite** validates actual DNS responses — not just syntax,
  but that records actually resolve correctly

The container is pre-built and available at
`ghcr.io/fini-net/fini-coredns-example` if you want to kick the tires
without building anything locally.

## The Corefile is deliberately simple

One thing I wanted to show is that you don't need a complicated Corefile
to get something useful running. The container config is basically:

```text
.:53 {
    forward . 8.8.8.8 9.9.9.9
    log
    errors
}

example.com:53 {
    log
    errors
    file /zones/example.com.zone
}

example.org:53 {
    log
    errors
    file /zones/example.org.zone
}
```

That's it. The `file` plugin consuming DNSControl's BIND output is the
key insight here — the two tools compose really naturally and I don't
think enough people know that.

## The testing piece

After evaluating existing DNS test tools, none quite fit the bill for
validating a containerized CoreDNS setup, so I wrote a Go test suite
that queries the running container directly. It validates A, AAAA,
CNAME, TXT, NS, and MX records across both example domains:

```text
--- PASS: TestDNSRecords/www.example.com_CNAME_record (0.00s)
--- PASS: TestDNSRecords/server1.example.com_AAAA_record (0.00s)
--- PASS: TestDNSRecords/calendar.example.org_CNAME_record (0.00s)
--- PASS: TestContainerHealthCheck (0.00s)
--- PASS: TestNSRecords (0.00s)
--- PASS: TestMXRecords (0.00s)
ok  github.com/fini-net/fini-coredns-example/test  0.220s
```

The whole workflow is driven by `just` recipes so you can clone it and
be running a DNS server in a few minutes.

## Why I'm posting here

A few things I'd love community input on:

1. **Is there a better pattern for testing CoreDNS in containers?** I
   looked at a few existing tools but nothing fit cleanly. Curious if
   others have solved this differently.

2. **Corefile patterns worth adding to the example?** Right now it's
   pretty minimal. Are there common configurations — health checks,
   metrics, ready plugin — that would make this more useful as a
   reference?

3. **Would something like this be useful as an official CoreDNS example?**
   I'd be happy to contribute it upstream if that's of interest.

All domains and IPs in the repo comply with RFC2606, RFC1918, and
RFC4193 so nothing conflicts with real infrastructure.

Feedback very welcome — including "you're doing this wrong, here's
the right way." That's exactly why I'm posting here.

— Christopher Hicks
