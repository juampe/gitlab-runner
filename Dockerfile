# syntax=docker/dockerfile:2
ARG UBUNTU="ubuntu:impish"
FROM ${UBUNTU}

ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"
ARG RUNNER="14.5.0"

#https://github.com/carlosedp/riscv-bringup/blob/master/build-docker-env.md

RUN cat /etc/apt/sources.list|sed -e 's/^deb /deb-src /' | sort -u >> /etc/apt/sources.list && \
  apt-get -y update && \
  apt-get -y upgrade && \
  apt-get -y install ca-certificates wget curl git apt-transport-https vim make cmake golang build-essential \
  apt-build debhelper-compat dh-apparmor dh-golang libseccomp-dev libseccomp2 libapparmor-dev pkg-config runc crun containerd \
    conntrack ebtables ethtool iproute2 iptables socat \
    bash-completion btrfs-progs && \
    cd /tmp && \
    wget https://github.com/carlosedp/riscv-bringup/releases/download/v1.0/docker-v20.10.2-dev_riscv64.deb && \
    dpkg -i /tmp/docker-v20.10.2-dev_riscv64.deb || true && \
    git clone https://gitlab.com/gitlab-org/gitlab-runner.git /runner && \
    cd /runner && \
    git checkout v${RUNNER} -f && \
    echo 'replace github.com/kr/pty => github.com/creack/pty latest' >> go.mod && \
    go mod download github.com/kr/pty && \
    LDFLAGS=$(make print_ldflags) && \
    go build -ldflags "$LDFLAGS" gitlab.com/gitlab-org/gitlab-runner && \
    cp gitlab-runner /usr/local/bin && \
    /usr/local/bin/gitlab-runner -version && \
    rm -R /runner /tmp/* && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

ADD entrypoint /
#RUN chmod +x /entrypoint

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]
ENTRYPOINT ["/entrypoint"]
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]


# RUN mkdir /docker && \
#   cd /docker && \
#   fakeroot apt-get source docker.io && \
#   cd docker.io-* && \
#   #echo 'replace github.com/Sirupsen/logrus => github.com/sirupsen/logrus v1.8.1' >> go.mod && \
#   #go mod edit -module=github.com/Sirupsen/logrus && \
#   #go get github.com/docker/docker/cmd/dockerd && \
# #  go mod edit -module=github.com/docker/libnetwork/cmd/proxy && \
# #  go get github.com/docker/libnetwork/cmd/proxy
# git clone https://anonscm.debian.org/git/docker/docker.io.git /docker.io && \
# cd /docker.io && \
#   mv docker.io/debian . && \
#   git clone https://github.com/docker/cli.git && cd cli && git checkout v20.10.11 -f && cd .. && \
#   git clone https://github.com/docker/engine.git && cd engine && git checkout v19.03.9  -f && cd .. && \
#   git clone https://github.com/docker/libnetwork.git && cd libnetwork && git checkout v0.7.2-rc.1 -f && cd .. && \
#   git clone https://github.com/docker/swarmkit.git && cd swarmkit && git checkout v1.12.0 -f && cd .. && \
#   fakeroot dpkg-buildpackage -d 
#   #git clone https://anonscm.debian.org/git/docker/docker.io.git
#   #fakeroot dpkg-buildpackage -d && \
#   #apt-get build-dep docker.io && \
#   #apt-build build-source docker.io -d
# #apt-get -y clean && \
#  #rm -rf /var/lib/apt/lists/*