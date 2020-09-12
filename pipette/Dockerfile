FROM registry.fedoraproject.org/fedora-minimal
ARG FEDORA=32
ARG VERSION=1.6
ADD https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA}/Cloud/aarch64/images/Fedora-Cloud-Base-${FEDORA}-${VERSION}.aarch64.qcow2 /
ADD https://download.fedoraproject.org/pub/fedora-secondary/releases/${FEDORA}/Cloud/ppc64le/images/Fedora-Cloud-Base-${FEDORA}-${VERSION}.ppc64le.qcow2 /
ADD https://download.fedoraproject.org/pub/fedora-secondary/releases/${FEDORA}/Cloud/s390x/images/Fedora-Cloud-Base-${FEDORA}-${VERSION}.s390x.qcow2 /
ADD https://download.fedoraproject.org/pub/fedora/linux/releases/${FEDORA}/Cloud/x86_64/images/Fedora-Cloud-Base-${FEDORA}-${VERSION}.x86_64.qcow2 /
RUN microdnf -y install buildah genisoimage git golang jq qemu skopeo && microdnf clean all
ADD pipette-arch.sh pipette-list.sh /
ENV STORAGE_DRIVER vfs
ENV ARCH=x86_64
ENV DOCKERFILE=Dockerfile
ENV BUILDCONTEXT=/buildcontext
ENV BUILDOUTPUT=/buildoutput
