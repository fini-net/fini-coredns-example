var GOOGLE_APPS_MX_RECORDS = [
	    MX("@", 1, "aspmx.l.google.com."),
	    MX("@", 5, "alt1.aspmx.l.google.com."),
	    MX("@", 5, "alt2.aspmx.l.google.com."),
	    MX("@", 10, "alt3.aspmx.l.google.com."),
	    MX("@", 10, "alt4.aspmx.l.google.com."),
]

var GOOGLE_APPS_CNAME_RECORDS = [
	    CNAME("calendar", "ghs.googlehosted.com."),
	    CNAME("drive", "ghs.googlehosted.com."),
	    CNAME("mail", "ghs.googlehosted.com."),
	    CNAME("groups", "ghs.googlehosted.com."),
	    CNAME("sites", "ghs.googlehosted.com."),
	    CNAME("start", "ghs.googlehosted.com."),
]

D("example.org", REG_NONE,
	DnsProvider(DNS_BIND),
	DefaultTTL(3600),
	NAMESERVER_TTL("3600"),
	//SOA("@", "ns0.example.com.", "info.example.com.", 38, 1200, 600, 604800, 3600),
	GOOGLE_APPS_MX_RECORDS,
	GOOGLE_APPS_CNAME_RECORDS,
	A("@", "10.1.0.11"),
	A("www", "10.1.0.12"),
END);
