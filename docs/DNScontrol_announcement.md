# DNSControl + CoreDNS Container Example - Announcement

Subject: New Complete Example: DNSControl → CoreDNS Container with Automated Testing

---

Hello DNSControl Community,

I'm excited to share a comprehensive example repository that demonstrates the complete workflow from DNSControl JavaScript configurations to a production-ready containerized DNS server:

**🔗 Repository**: [https://github.com/fini-net/fini-coredns-example](https://github.com/fini-net/fini-coredns-example)

## What This Provides

This repository showcases a real-world implementation of:

- **JavaScript DNS Configuration**: Clean, maintainable DNS record definitions using DNSControl syntax
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
just push        # Generate BIND files from JavaScript
just build_con   # Build CoreDNS container
just run_con     # Start DNS server on port 1029
just test_dns    # Run automated test suite
```

## Why This Matters

Many teams struggle with the gap between DNSControl configuration and actual
DNS service deployment. This repository bridges that gap by providing:

1. **Real-world patterns** for organizing DNS configurations
2. **Container-first deployment** approach
3. **Automated validation** ensuring DNS changes work as expected
4. **Development workflow** suitable for CI/CD integration

The testing component is particularly valuable - it validates not just that
zones compile, but that they actually resolve correctly when served.

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
