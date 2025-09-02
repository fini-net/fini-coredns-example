package test

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/miekg/dns"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	containerName = "coredns-test"
	containerPort = "1029"
	dnsServer     = "127.0.0.1:" + containerPort
	timeout       = 30 * time.Second
)

// TestRecord defines a DNS record to test
type TestRecord struct {
	Name     string
	Type     uint16
	Expected []string
	Desc     string
}

// checkContainer verifies the CoreDNS container is already running
func checkContainer(t *testing.T) {
	t.Helper()

	// Check if container is running on the expected port
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	for {
		select {
		case <-ctx.Done():
			t.Fatal("Container is not responding on port " + containerPort + ". Please start it with: podman run -d --name corednstest -p 1029:53/udp fini-coredns-example")
		default:
			_, err := queryDNS("example.com", dns.TypeA)
			if err == nil {
				return // Container is ready
			}
			time.Sleep(500 * time.Millisecond)
		}
	}
}

// queryDNS performs a DNS query and returns the results
func queryDNS(name string, qtype uint16) (*dns.Msg, error) {
	c := new(dns.Client)
	c.Timeout = 5 * time.Second

	m := new(dns.Msg)
	m.SetQuestion(dns.Fqdn(name), qtype)
	m.RecursionDesired = true

	r, _, err := c.Exchange(m, dnsServer)
	if err != nil {
		return nil, err
	}

	return r, nil
}

// extractAnswers extracts answer values from DNS response
func extractAnswers(r *dns.Msg, qtype uint16) []string {
	var answers []string
	for _, ans := range r.Answer {
		switch qtype {
		case dns.TypeA:
			if a, ok := ans.(*dns.A); ok {
				answers = append(answers, a.A.String())
			}
		case dns.TypeAAAA:
			if aaaa, ok := ans.(*dns.AAAA); ok {
				answers = append(answers, aaaa.AAAA.String())
			}
		case dns.TypeCNAME:
			if cname, ok := ans.(*dns.CNAME); ok {
				answers = append(answers, strings.TrimSuffix(cname.Target, "."))
			}
		case dns.TypeMX:
			if mx, ok := ans.(*dns.MX); ok {
				answers = append(answers, fmt.Sprintf("%d %s", mx.Preference,
					strings.TrimSuffix(mx.Mx, ".")))
			}
		case dns.TypeTXT:
			if txt, ok := ans.(*dns.TXT); ok {
				answers = append(answers, strings.Join(txt.Txt, ""))
			}
		case dns.TypeNS:
			if ns, ok := ans.(*dns.NS); ok {
				answers = append(answers, strings.TrimSuffix(ns.Ns, "."))
			}
		}
	}
	return answers
}

// TestDNSRecords tests specific DNS records against the container
func TestDNSRecords(t *testing.T) {
	checkContainer(t)

	testRecords := []TestRecord{
		// example.com A records
		{
			Name:     "example.com",
			Type:     dns.TypeA,
			Expected: []string{"10.0.0.101"},
			Desc:     "example.com root A record",
		},
		{
			Name:     "server1.example.com",
			Type:     dns.TypeA,
			Expected: []string{"10.0.0.101"},
			Desc:     "server1.example.com A record",
		},
		{
			Name:     "ns0.example.com",
			Type:     dns.TypeA,
			Expected: []string{"10.0.0.10"},
			Desc:     "ns0.example.com A record",
		},
		// example.com CNAME records
		{
			Name:     "www.example.com",
			Type:     dns.TypeCNAME,
			Expected: []string{"server1.example.com"},
			Desc:     "www.example.com CNAME record",
		},
		{
			Name:     "ftp.example.com",
			Type:     dns.TypeCNAME,
			Expected: []string{"server1.example.com"},
			Desc:     "ftp.example.com CNAME record",
		},
		// example.com AAAA record
		{
			Name:     "server1.example.com",
			Type:     dns.TypeAAAA,
			Expected: []string{"fc00:abcd:ef01:2345:6789:123:4567:8901"},
			Desc:     "server1.example.com AAAA record",
		},
		// example.com TXT record
		{
			Name:     "server1.example.com",
			Type:     dns.TypeTXT,
			Expected: []string{"in the lab somewhere"},
			Desc:     "server1.example.com TXT record",
		},
		// example.org records
		{
			Name:     "example.org",
			Type:     dns.TypeA,
			Expected: []string{"10.1.0.11"},
			Desc:     "example.org root A record",
		},
		{
			Name:     "www.example.org",
			Type:     dns.TypeA,
			Expected: []string{"10.1.0.12"},
			Desc:     "www.example.org A record",
		},
		{
			Name:     "calendar.example.org",
			Type:     dns.TypeCNAME,
			Expected: []string{"ghs.googlehosted.com"},
			Desc:     "calendar.example.org CNAME record",
		},
	}

	for _, test := range testRecords {
		t.Run(test.Desc, func(t *testing.T) {
			// Query DNS
			r, err := queryDNS(test.Name, test.Type)
			require.NoError(t, err, "DNS query failed for %s", test.Name)
			require.NotNil(t, r, "No response received")
			require.Equal(t, dns.RcodeSuccess, r.Rcode, "DNS query returned error code")
			require.NotEmpty(t, r.Answer, "No answers received for %s", test.Name)

			// Extract answers
			answers := extractAnswers(r, test.Type)
			require.NotEmpty(t, answers, "Failed to extract answers from response")

			// Validate expected results
			for _, expected := range test.Expected {
				assert.Contains(t, answers, expected,
					"Expected answer %s not found in response %v", expected, answers)
			}
		})
	}
}

// TestContainerHealthCheck verifies the container is responding
func TestContainerHealthCheck(t *testing.T) {
	checkContainer(t)

	// Test basic connectivity with a simple query
	r, err := queryDNS("example.com", dns.TypeA)
	require.NoError(t, err, "Health check DNS query failed")
	require.NotNil(t, r, "No response received")
	require.Equal(t, dns.RcodeSuccess, r.Rcode, "DNS query returned error code")
}

// TestNSRecords tests NS records specifically
func TestNSRecords(t *testing.T) {
	checkContainer(t)

	expectedNS := []string{
		"ns0.example.com",
		"ns1.example.com",
		"ns2.example.com",
		"ns3.example.com",
	}

	r, err := queryDNS("example.com", dns.TypeNS)
	require.NoError(t, err, "NS query failed")
	require.Equal(t, dns.RcodeSuccess, r.Rcode)
	require.NotEmpty(t, r.Answer, "No NS records returned")

	answers := extractAnswers(r, dns.TypeNS)
	require.Len(t, answers, 4, "Expected 4 NS records")

	for _, expected := range expectedNS {
		assert.Contains(t, answers, expected, "Missing NS record: %s", expected)
	}
}

// TestMXRecords tests MX records for both domains
func TestMXRecords(t *testing.T) {
	checkContainer(t)

	testCases := []struct {
		domain   string
		expected []string
	}{
		{
			domain: "example.com",
			expected: []string{
				"10 mx0.example.com",
				"30 mx3.example.com",
				"40 mx4.example.com",
				"50 mx5.example.com",
				"60 mx6.example.com",
			},
		},
		{
			domain: "example.org",
			expected: []string{
				"1 aspmx.l.google.com",
				"5 alt1.aspmx.l.google.com",
				"5 alt2.aspmx.l.google.com",
				"10 alt3.aspmx.l.google.com",
				"10 alt4.aspmx.l.google.com",
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.domain, func(t *testing.T) {
			r, err := queryDNS(tc.domain, dns.TypeMX)
			require.NoError(t, err, "MX query failed for %s", tc.domain)
			require.Equal(t, dns.RcodeSuccess, r.Rcode)
			require.NotEmpty(t, r.Answer, "No MX records returned for %s", tc.domain)

			answers := extractAnswers(r, dns.TypeMX)
			require.Len(t, answers, len(tc.expected),
				"Expected %d MX records for %s", len(tc.expected), tc.domain)

			for _, expected := range tc.expected {
				assert.Contains(t, answers, expected,
					"Missing MX record for %s: %s", tc.domain, expected)
			}
		})
	}
}
