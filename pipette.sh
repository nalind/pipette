#!/bin/bash
set -ex

# Build the builder.
IMAGE=quay.io/nalind/pipette
# podman build -t ${IMAGE} pipette

# Check out the build context.
REPOSITORY=${REPOSITORY:-https://github.com/containers/buildah}
VERSION=${VERSION:-v1.16.1}
DOCKERFILE=contrib/buildahimage/stable/Dockerfile
mkdir -p build/context build/output
podman run --rm -it -v $(pwd)/build/context:/buildcontext:Z ${IMAGE} git clone ${REPOSITORY} /buildcontext
podman run --rm -it -v $(pwd)/build/context:/buildcontext:Z ${IMAGE} sh -c "cd /buildcontext; git checkout ${VERSION}"

# Build the per-arch images.
: > build/cid.txt
for arch in ${ARCH:-x86_64}; do
	mkdir -p build/output/${arch}/image
	if test -s build/cid-${arch}.txt ; then
		cat build/cid-${arch}.txt >> build/cid.txt
		continue
	fi
	podman run --rm -d --cidfile build/cid-${arch}.txt -v $(pwd)/build/context:/buildcontext:Z -v $(pwd)/build/output/${arch}:/buildoutput:Z -e ARCH="${arch}" -e DOCKERFILE="${DOCKERFILE}" ${IMAGE} /pipette-arch.sh
	cat build/cid-${arch}.txt >> build/cid.txt
done
podman wait $(cat build/cid.txt)

# Build the multi-arch image using the per-arch images.
podman run --rm -it -v $(pwd)/build/output:/buildoutput:Z ${IMAGE} /pipette-list.sh
skopeo inspect --raw dir:build/list | jq
