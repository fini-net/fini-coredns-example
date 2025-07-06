FROM coredns/coredns

COPY Container_root/Corefile /etc/Corefile
COPY dns/zones/*.zone /zones/
