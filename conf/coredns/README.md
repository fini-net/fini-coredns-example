# conf/coredns

Configs for coredns.

## usage

Run `coredns` in this directory and it should serve
the two example domains from elsewhere in this repo.

## server logs

```bash
% coredns
example.com.:5300
example.org.:5300
CoreDNS-1.11.4
darwin/arm64, go1.23.2,
[INFO] 127.0.0.1:51508 - 46027 "A IN www.example.com. udp 44 false 4096" NOERROR qr,aa,rd 276 0.000500625s
[INFO] 127.0.0.1:60282 - 1668 "A IN www.example.com. udp 44 false 4096" NOERROR qr,aa,rd 276 0.000183875s
[INFO] 127.0.0.1:59613 - 18579 "A IN calendar.example.org. udp 49 false 4096" NOERROR qr,aa,rd 252 0.000529333s
[INFO] 127.0.0.1:60743 - 3433 "NS IN example.com. udp 40 false 4096" NOERROR qr,aa,rd 313 0.000224542s
^C[INFO] SIGINT: Shutting down
```

## client logs

```bash
% dig @localhost -p 5300 www.example.com
; <<>> DiG 9.10.6 <<>> @localhost -p 5300 www.example.com
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 1668
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 4, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.example.com.		IN	A

;; ANSWER SECTION:
www.example.com.	3600	IN	CNAME	server1.example.com.
server1.example.com.	3600	IN	A	10.0.0.101

;; AUTHORITY SECTION:
example.com.		3600	IN	NS	ns0.example.com.
example.com.		3600	IN	NS	ns1.example.com.
example.com.		3600	IN	NS	ns2.example.com.
example.com.		3600	IN	NS	ns3.example.com.

;; Query time: 0 msec
;; SERVER: 127.0.0.1#5300(127.0.0.1)
;; WHEN: Sun Jun 15 19:18:07 EDT 2025
;; MSG SIZE  rcvd: 287

```

```bash
% dig @localhost -p 5300 calendar.example.org

; <<>> DiG 9.10.6 <<>> @localhost -p 5300 calendar.example.org
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 18579
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 4, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;calendar.example.org.		IN	A

;; ANSWER SECTION:
calendar.example.org.	3600	IN	CNAME	ghs.googlehosted.com.

;; AUTHORITY SECTION:
example.org.		3600	IN	NS	ns0.example.com.
example.org.		3600	IN	NS	ns1.example.com.
example.org.		3600	IN	NS	ns2.example.com.
example.org.		3600	IN	NS	ns3.example.com.

;; Query time: 0 msec
;; SERVER: 127.0.0.1#5300(127.0.0.1)
;; WHEN: Sun Jun 15 19:18:30 EDT 2025
;; MSG SIZE  rcvd: 263

```

```bash
% dig @localhost -p 5300 example.com NS

; <<>> DiG 9.10.6 <<>> @localhost -p 5300 example.com NS
; (2 servers found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 3433
;; flags: qr aa rd; QUERY: 1, ANSWER: 4, AUTHORITY: 0, ADDITIONAL: 5
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;example.com.			IN	NS

;; ANSWER SECTION:
example.com.		3600	IN	NS	ns0.example.com.
example.com.		3600	IN	NS	ns1.example.com.
example.com.		3600	IN	NS	ns2.example.com.
example.com.		3600	IN	NS	ns3.example.com.

;; ADDITIONAL SECTION:
ns0.example.com.	3600	IN	A	10.0.0.10
ns1.example.com.	3600	IN	A	10.0.0.11
ns2.example.com.	3600	IN	A	10.0.0.12
ns3.example.com.	3600	IN	A	10.0.0.13

;; Query time: 0 msec
;; SERVER: 127.0.0.1#5300(127.0.0.1)
;; WHEN: Sun Jun 15 19:19:08 EDT 2025
;; MSG SIZE  rcvd: 324

```
