// Defaults
var REG_NONE = NewRegistrar("none");
var DNS_BIND = NewDnsProvider("bind", {
	"default_soa": {
		"master": "ns0.example.com.",
		"mbox": "info.example.com.",
		"refresh": 1200, // 20 minutes
		"retry": 600, // 10 minutes
		"expire": 604800, // 1 week
		"minttl": 3600, // 1 hour
	},
	"default_ns": [
		"ns0.example.com.",
		"ns1.example.com.",
		"ns2.example.com.",
		"ns3.example.com.",
	]
});

// MX
function add_mx(hostname) {
	return([
		MX(hostname, 10, "mx0.example.com."),
		MX(hostname, 30, "mx3.example.com."),
		MX(hostname, 40, "mx4.example.com."),
		MX(hostname, 50, "mx5.example.com."),
		MX(hostname, 60, "mx6.example.com."),
	END])
}

// Default Domain
function default_domain() {
	return([
		A("@", "10.0.0.101"),
		add_mx("@"),

		A("server1", "10.0.0.101"),
		AAAA("server1", "fc00:abcd:ef01:2345:6789:0123:4567:8901", TTL("4h")),
		add_mx("server1"),
		TXT("server1", "in the lab somewhere"),
		CNAME("www","server1"),
		CNAME("ftp","server1"),

		A("ns0", "10.0.0.10"),
		add_mx("ns0"),
		A("ns1", "10.0.0.11"),
		add_mx("ns1"),
		A("ns2", "10.0.0.12"),
		add_mx("ns2"),
		A("ns3", "10.0.0.13"),
		add_mx("ns3"),

		A("mx0", "10.0.0.10"),
		add_mx("mx0"),
		A("mx3", "10.0.0.13"),
		add_mx("mx3"),
		A("mx4", "10.0.0.14"),
		add_mx("mx4"),
		A("mx5", "10.0.0.15"),
		add_mx("mx5"),
		A("mx6", "10.0.0.16"),
		add_mx("mx6"),
	END]);
}

// example domains
var example_com_include = require('./example.com.js');
var example_org_include = require('./example.org.js');
