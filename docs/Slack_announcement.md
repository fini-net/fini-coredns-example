# CoreDNS + DNSControl Example Repository

Hey folks! 👋

Just wanted to share a repo I've been working on that demonstrates how to manage DNS zones using DNSControl and serve them with CoreDNS.

**What is it?**
A practical example showing how to define DNS records in JavaScript (using DNSControl) and automatically generate BIND zone files that CoreDNS can serve. Think "infrastructure as code" but for DNS.

**Why might you care?**

- If you're tired of manually editing zone files
- Want version control for your DNS configurations
- Need to test DNS setups locally before deploying
- Curious about running DNS servers in containers

**What's included:**

- Example DNS configs for `example.com` and `example.org` (all RFC-compliant test domains/IPs)
- Ready-to-run CoreDNS container setup
- Justfile with commands for the full workflow (preview changes, generate zones, build/run containers)
- GitHub Actions for automated testing and container publishing

**Quick start:**
Clone it, run `just preview` to see what DNS changes would look like, then `just run_con` to spin up a local DNS server. Query it with dig and you're testing DNS configurations locally.

Check it out: <https://github.com/fini-net/fini-coredns-example>

Happy to answer questions or hear feedback if anyone wants to play with it!
