#!/bin/bash
set -ex
# Build the builder.
IMAGE=quay.io/nalind/pipette
podman build -t ${IMAGE} pipette
# Check out the build context.
VERSION=v1.6.1
mkdir -p build/context build/output
podman run --rm -it -v build/context:/buildcontext ${IMAGE} git clone https://github.com/containers/buildah /buildcontext
podman run --rm -it -v build/context:/buildcontext ${IMAGE} sh -c "cd /buildcontext; git checkout ${VERSION}"
# Build the per-arch images.
: > build/cid.txt
for arch in ${ARCH:-x86_64}; do
	mkdir -p build/output/${arch}/image
	if test -s build/cid-${arch}.txt ; then
		cat build/cid-${arch}.txt >> build/cid.txt
		continue
	fi
	podman run --rm -d --cidfile build/cid-${arch}.txt -v build/context:/buildcontext -v build/output/${arch}:/buildoutput -e ARCH=${arch} ${IMAGE} /pipette-arch.sh
	cat build/cid-${arch}.txt >> build/cid.txt
done
podman wait $(cat build/cid.txt)
# Build the multi-arch image.
podman run --rm -it -v build/output:/buildoutput ${IMAGE} /pipette-list.sh
skopeo inspect --raw dir:build/list | jq
