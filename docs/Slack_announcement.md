# CoreDNS + DNSControl Example Repository

Hey folks! 👋

Just wanted to share a repo that demonstrates managing DNS zones using DNSControl and serving them with CoreDNS.

**What is it?**
Define DNS records in JavaScript (using DNSControl) and automatically generate BIND zone files that CoreDNS serves. Think "infrastructure as code" but for DNS.

**Why might you care?**

- Tired of manually editing zone files
- Want version control for DNS configurations
- Need to test DNS setups locally before deploying

**What's included:**
Example configs, containerized CoreDNS setup, and justfile commands for the full workflow (preview, generate, build/run).

**Quick start:**
Run `just preview` to see DNS changes, then `just run_con` to spin up a local DNS server. Query it with dig.

Check it out: <https://github.com/fini-net/fini-coredns-example>

Happy to answer questions!
