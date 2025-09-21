# DNS Configuration

This directory contains DNSControl configuration files and generated BIND zone files for managing DNS records.

## File Structure

### Configuration Files

- **`dnsconfig.js`** - Main DNSControl configuration with shared functions, default SOA settings, and common record templates
- **`example.com.js`** - Domain-specific configuration for example.com
- **`example.org.js`** - Domain-specific configuration for example.org  
- **`creds.json`** - DNSControl provider credentials (BIND and OpenSRS)

### Generated Files

- **`zones/`** - Directory containing generated BIND zone files
  - `example.com.zone` - Generated zone file for example.com
  - `example.org.zone` - Generated zone file for example.org

## DNSControl Syntax Reference

### Domain Declaration

```javascript
D("domain.com", REG_NONE,
    DnsProvider(DNS_BIND),
    DefaultTTL(3600),
    NAMESERVER_TTL("3600"),
    // records go here
END);
```

### Record Types

#### A Records (IPv4)

```javascript
A("hostname", "192.168.1.100")
A("@", "10.0.0.1")  // @ represents the domain apex
```

#### AAAA Records (IPv6)

```javascript
AAAA("hostname", "2001:db8::1")
AAAA("server1", "fc00:abcd:ef01:2345:6789:0123:4567:8901", TTL("4h"))
```

#### CNAME Records

```javascript
CNAME("www", "server1")
CNAME("mail", "ghs.googlehosted.com.")
```

#### MX Records

```javascript
MX("@", 10, "mail.example.com.")
MX("@", 20, "backup-mail.example.com.")
```

#### TXT Records

```javascript
TXT("@", "v=spf1 include:_spf.google.com ~all")
TXT("server1", "in the lab somewhere")
```

#### NS Records

```javascript
NS("subdomain", "ns1.example.com.")
```

### TTL Configuration

```javascript
DefaultTTL(3600)  // Set default TTL for all records
TTL("4h")         // Custom TTL for specific record
NAMESERVER_TTL("3600")  // TTL for nameserver records
```

### Functions and Variables

#### Reusable Functions

```javascript
function add_mx(hostname) {
    return([
        MX(hostname, 10, "mx0.example.com."),
        MX(hostname, 20, "mx1.example.com."),
    END])
}
```

#### Variable Arrays

```javascript
var GOOGLE_MX = [
    MX("@", 1, "aspmx.l.google.com."),
    MX("@", 5, "alt1.aspmx.l.google.com."),
]
```

### Provider Configuration

```javascript
var DNS_BIND = NewDnsProvider("bind", {
    "default_soa": {
        "master": "ns0.example.com.",
        "mbox": "info.example.com.",
        "refresh": 1200,
        "retry": 600,
        "expire": 604800,
        "minttl": 3600,
    },
    "default_ns": [
        "ns0.example.com.",
        "ns1.example.com.",
    ]
});
```

## Usage

1. **Preview changes**: `just preview` - Shows what changes would be made
2. **Generate zones**: `just push` - Creates BIND zone files from JS configurations
3. **Test locally**: Use CoreDNS with generated zone files

## Best Practices

- Use RFC1918 private IP ranges (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12)
- Use RFC4193 IPv6 unique local addresses (fc00::/7)  
- Always end hostnames with periods when they're FQDNs
- Use the `@` symbol to reference the domain apex
- Group related records with functions and variables for maintainability
- Test changes with `just preview` before applying with `just push`
