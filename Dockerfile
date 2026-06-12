# checkov:skip=CKV_DOCKER_7:pinning coredns base image is not desired
FROM coredns/coredns

ARG BUILD_VERSION
ARG PROJECT_URL="https://github.com/fini-net/fini-coredns-example"

# TODO: include "generated with" line from zone file as a LABEL
LABEL \
  org.opencontainers.image.title="FINI coredns demo with dnscontrol" \
  org.opencontainers.image.description="FINI coredns demo with dnscontrol" \
  org.opencontainers.image.url="$PROJECT_URL" \
  org.opencontainers.image.source="$PROJECT_URL" \
  org.opencontainers.image.documentation="$PROJECT_URL" \
  org.opencontainers.image.version="$BUILD_VERSION" \
  org.opencontainers.image.license="GPL2" \
  org.opencontainers.image.vendor="FINI.net" \
  org.opencontainers.image.authors="Christopher Hicks <chicks.net@gmail.com>" \
  author="Christopher Hicks <chicks.net@gmail.com>" \
  maintainer="Christopher Hicks <chicks.net@gmail.com>"

# config file for coredns
COPY Container_root/Corefile /etc/Corefile
# DNS zone files
COPY dns/zones/*.zone /zones/

USER nonroot:nonroot

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD [ "/coredns", "-version" ]
