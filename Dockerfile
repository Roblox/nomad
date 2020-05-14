FROM alpine:3.6

LABEL maintainer="DJ Enriquez <denrie.enriquezjr@gmail.com> (@djenriquez)"

RUN addgroup nomad && \
    adduser -S -G nomad nomad

ENV GLIBC_VERSION "2.25-r0"
ENV GOSU_VERSION 1.10
ENV DUMB_INIT_VERSION 1.2.0

# import gosu key
ADD gosu.asc /root/gosu.asc
# import hashicorp key
ADD hashicorp.asc /root/hashicorp.asc

RUN set -x && \
    apk --update add --no-cache --virtual .gosu-deps dpkg curl -f gnupg && \
    curl -f -L -o /tmp/glibc-${GLIBC_VERSION}.apk https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    apk add --allow-untrusted /tmp/glibc-${GLIBC_VERSION}.apk && \
    rm -rf /tmp/glibc-${GLIBC_VERSION}.apk /var/cache/apk/* && \
    curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    curl -f -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    curl -f -L -o /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --import /root/gosu.asc && \
    gpg --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -rf "$GNUPGHOME" && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true && \
    apk del .gosu-deps

ENV NOMAD_VERSION 0.9.7

RUN set -x \
  && apk --update add --no-cache --virtual .nomad-deps gnupg curl -f \
  && cd /tmp \
  && curl -f -L -o nomad-enterprise_${NOMAD_VERSION}+ent_linux_amd64.zip https://cdn.aws.robloxlabs.com/nomad/${NOMAD_VERSION}/nomad-enterprise_${NOMAD_VERSION}%2bent_linux_amd64.zip \
  && curl -f -L -o nomad_${NOMAD_VERSION}_SHA256SUMS      https://cdn.aws.robloxlabs.com/nomad/${NOMAD_VERSION}/nomad-enterprise_${NOMAD_VERSION}%2bent_SHA256SUMS \
  && curl -f -L -o nomad_${NOMAD_VERSION}_SHA256SUMS.sig  https://cdn.aws.robloxlabs.com/nomad/${NOMAD_VERSION}/nomad-enterprise_${NOMAD_VERSION}%2bent_SHA256SUMS.sig \
  && cat nomad_${NOMAD_VERSION}_SHA256SUMS \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --import /root/hashicorp.asc \
  && gpg --verify nomad_${NOMAD_VERSION}_SHA256SUMS.sig nomad_${NOMAD_VERSION}_SHA256SUMS \
  && grep nomad-enterprise_${NOMAD_VERSION}+ent_linux_amd64.zip nomad_${NOMAD_VERSION}_SHA256SUMS | sha256sum -c \
  && unzip -d /bin nomad-enterprise_${NOMAD_VERSION}+ent_linux_amd64.zip \
  && chmod +x /bin/nomad \
  && rm -rf "$GNUPGHOME" nomad-enterprise_${NOMAD_VERSION}+ent_linux_amd64.zip nomad_${NOMAD_VERSION}_SHA256SUMS nomad_${NOMAD_VERSION}_SHA256SUMS.sig \
  && apk del .nomad-deps
  
RUN set -x \
  && apk --update add --no-cache ca-certificates openssl \
  && update-ca-certificates


RUN mkdir -p /nomad/data && \
    mkdir -p /etc/nomad && \
    chown -R nomad:nomad /nomad

EXPOSE 4646 4647 4648 4648/udp

ADD start.sh /usr/local/bin/start.sh

ENTRYPOINT ["/usr/local/bin/start.sh"]
