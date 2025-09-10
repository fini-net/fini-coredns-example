# DNSControl + CoreDNS Container Example - Announcement

Subject: New Complete Example: DNSControl → CoreDNS Container with Automated Testing

---

Howdy DNSControl Community,

I'm excited to share a comprehensive example repository that demonstrates the complete workflow from DNSControl JavaScript configurations to a production-ready containerized DNS server:

**🔗 Repository**: [https://github.com/fini-net/fini-coredns-example](https://github.com/fini-net/fini-coredns-example)

## What This Provides

This repository showcases a real-world implementation of:

- **JavaScript DNS Configuration**: Clean, maintainable DNS record definitions using DNSControl syntax
- **DNSControl → CoreDNS Integration**: Many don't realize that DNSControl's BIND provider generates zone files that CoreDNS can serve directly!
- **Automated BIND Zone Generation**: `dnscontrol push` converts JS configs to standard BIND zone files
- **Containerized DNS Server**: CoreDNS container serving the generated zones (available in GHCR)
- **Comprehensive Testing**: Go test suite validating DNS responses for A, AAAA, CNAME, TXT, NS, and MX records
- **Complete Development Workflow**: `just` command recipes for the entire build → test → deploy cycle

## Key Features

- **Two Example Domains**: `example.com` (traditional setup) and `example.org` (Google Workspace integration)
- **RFC Compliance**: Uses reserved domains (RFC2606) and private IP ranges (RFC1918/RFC4193)
- **Automated Testing**: 10+ specific DNS record validations with detailed test output
- **Container Registry**: Pre-built images available at `ghcr.io/fini-net/fini-coredns-example`
- **Documentation**: Complete setup instructions and usage examples

## Quick Demo

```bash
git clone https://github.com/fini-net/fini-coredns-example
cd fini-coredns-example
just push        # Generate BIND files from JavaScript (optional, already in the container)
just build_con   # Build CoreDNS container (optional, container is in GHCR)
just run_con     # Start DNS server on port 1029
just test_quick  # Run quick test (just a dig)
just test_dns    # Run automated test suite (written in Golang)
```

## Why This Matters

If you're already using DNSControl to manage your DNS configurations, you've probably wondered about the next step: how do you actually serve those zones reliably? This repository addresses common sysadmin challenges:

1. **"How do I test my DNS changes before they go live?"** - Automated Go tests validate actual DNS responses, not just config syntax
2. **"Can I run my own authoritative DNS without BIND complexity?"** - CoreDNS provides a simpler, container-native alternative that directly consumes DNSControl's BIND output
3. **"How do I integrate DNS deployment into modern infrastructure?"** - Complete containerization with pre-built GHCR images and `just` workflow automation
4. **"What's the path from DNSControl development to production DNS service?"** - End-to-end example from JavaScript configs to running DNS server

The testing component is particularly valuable for sysadmins - it validates not just that your DNSControl configs compile, but that they actually resolve correctly when served to clients. No more deploying DNS changes and hoping they work!

## Use Cases

- **Learning DNSControl**: See practical JavaScript DNS configurations in action
- **Container Deployment**: Reference implementation for containerized DNS services
- **Testing Patterns**: Example of automated DNS validation
- **CI/CD Integration**: Templates for automated DNS deployment workflows

I hope this helps teams looking to implement robust DNS management workflows.
The repository includes comprehensive documentation and follows DNS best
practices throughout.

Feedback and contributions are very welcome!

Best regards,
Christopher Hicks
