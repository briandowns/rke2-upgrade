ARG BCI_IMAGE=registry.suse.com/bci/bci-base:15.3.17.20.57
FROM ${BCI_IMAGE} AS verify
ARG ARCH
ARG TAG
WORKDIR /verify
ADD https://github.com/rancher/rke2/releases/download/${TAG}/sha256sum-${ARCH}.txt .
RUN set -x \
 && zypper -n update \
 && zypper -n install \
    curl \
    file
RUN export ARTIFACT="rke2.linux-${ARCH}" \
 && curl --output ${ARTIFACT}  --fail --location https://github.com/rancher/rke2/releases/download/${TAG}/${ARTIFACT} \
 && grep "rke2.linux-${ARCH}$" sha256sum-${ARCH}.txt | sha256sum -c \
 && mv -vf ${ARTIFACT} /opt/rke2 \
 && chmod +x /opt/rke2 \
 && file /opt/rke2

RUN set -x \
 && export K8S_RELEASE=$(echo ${TAG} | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+') \
 && curl -fsSLO https://storage.googleapis.com/kubernetes-release/release/${K8S_RELEASE}/bin/linux/${ARCH}/kubectl \
 && chmod +x kubectl

FROM ${BCI_IMAGE}
ARG ARCH
ARG TAG
RUN zypper -n update \
 && zypper -n install \
    jq selinux-tools gawk \
 && zypper -n clean -a && rm -rf /tmp/* /var/tmp/* /usr/share/doc/packages/* /usr/share/doc/manual/* /var/log/*
COPY --from=verify /opt/rke2 /opt/rke2
COPY scripts/upgrade.sh /bin/upgrade.sh
COPY scripts/semver-parse.sh /bin/semver-parse.sh
COPY --from=verify /verify/kubectl /usr/local/bin/kubectl
ENTRYPOINT ["/bin/upgrade.sh"]
CMD ["upgrade"]
