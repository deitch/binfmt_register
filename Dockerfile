FROM alpine:3.8
MAINTAINER Avi Deitcher <https://github.com/deitch>

ARG QEMU_VERSION=2.9.1-1

# list of archs we will support cross-running for
ARG QEMU_ARCHS="aarch64 ppc64le s390x"

# get necessary components
RUN apk --update add curl

# Enable non-native runs on amd64 architecture hosts
RUN for i in ${QEMU_ARCHS}; do curl -L https://github.com/multiarch/qemu-user-static/releases/download/v${QEMU_VERSION}/qemu-${i}-static.tar.gz | tar zxvf - -C /usr/bin; done
RUN chmod +x /usr/bin/qemu-*
COPY register.sh /usr/local/bin/register
COPY binfmt.conf /usr/local/etc/binfmt.conf

ENTRYPOINT ["/usr/local/bin/register"]

