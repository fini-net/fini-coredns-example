D("example.com", REG_NONE,
	DnsProvider(DNS_BIND),
	DefaultTTL(3600),
	NAMESERVER_TTL("3600"),
	//SOA("@", "ns0.example.com.", "info.example.com.", 38, 1200, 600, 604800, 3600),
	default_domain(),
END);
