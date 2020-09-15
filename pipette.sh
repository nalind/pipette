#!/bin/bash
set -ex

REPOSITORY="${REPOSITORY:-https://github.com/containers/buildah}"
VERSION=${VERSION:-v1.16.1}
DOCKERFILE="${DOCKERFILE:-contrib/buildahimage/stable/Dockerfile}"

# Build the builder image.
IMAGE=quay.io/nalind/pipette
podman build -t ${IMAGE} ./builder

# Check out the build context.
mkdir -p build/context build/output
podman run --rm -it -v "$(pwd)"/build/context:/buildcontext:z ${IMAGE} git clone "${REPOSITORY}" /buildcontext
podman run --rm -it -v "$(pwd)"/build/context:/buildcontext:z ${IMAGE} sh -c "cd /buildcontext; git checkout ${VERSION}"

# Start builds of the per-arch payload images.
: > build/cid.txt
for arch in ${ARCH:-aarch64 ppc64le s390x x86_64}; do
	if ! test -s build/cid-${arch}.txt ; then
		podman run -d --cidfile build/cid-${arch}.txt -v $(pwd)/build/context:/buildcontext:z -v $(pwd)/build/output:/buildoutput:z -e ARCH="${arch}" -e BUILDCONTEXT=/buildcontext -e BUILDOUTPUT=/buildoutput -e DOCKERFILE="${DOCKERFILE}" ${IMAGE} /build-arch.sh
	fi
	cat build/cid-${arch}.txt >> build/cid.txt
	echo " "                  >> build/cid.txt
done

# Wait for the builds to complete.
for cid in $(cat build/cid.txt) ; do
	podman wait $cid
done

# Build the multi-arch image using the per-arch images.
podman run --rm -it -v $(pwd)/build/output:/buildoutput:z -e BUILDOUTPUT=/buildoutput ${IMAGE} /build-list.sh
skopeo inspect --raw dir:build/output/list | jq
