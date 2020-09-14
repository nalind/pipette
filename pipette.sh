#!/bin/bash
set -ex

IMAGE=quay.io/nalind/pipette

# Check out the build context.
REPOSITORY=${REPOSITORY:-https://github.com/containers/buildah}
VERSION=${VERSION:-v1.16.1}
DOCKERFILE=${DOCKERFILE:-contrib/buildahimage/stable/Dockerfile}
mkdir -p build/context build/output
podman run --rm -it -v $(pwd)/build/context:/buildcontext:z ${IMAGE} git clone ${REPOSITORY} /buildcontext
podman run --rm -it -v $(pwd)/build/context:/buildcontext:z ${IMAGE} sh -c "cd /buildcontext; git checkout ${VERSION}"

# Build the per-arch images.
: > build/cid.txt
for arch in ${ARCH:-aarch64 ppc64le s390x x86_64}; do
	mkdir -p build/output/${arch}/image
	if test -s build/cid-${arch}.txt ; then
		cat build/cid-${arch}.txt >> build/cid.txt
		continue
	fi
	podman run -d --cidfile build/cid-${arch}.txt -v $(pwd)/build/context:/buildcontext:z -v $(pwd)/build/output/${arch}:/buildoutput:z -e ARCH="${arch}" -e DOCKERFILE="${DOCKERFILE}" ${IMAGE} /pipette-arch.sh
	cat build/cid-${arch}.txt >> build/cid.txt
	echo " "                  >> build/cid.txt
done
for cid in $(cat build/cid.txt) ; do
	podman wait $cid
done

# Build the multi-arch image using the per-arch images.
podman run --rm -it -v $(pwd)/build/output:/buildoutput:z ${IMAGE} /pipette-list.sh
skopeo inspect --raw dir:build/output/list | jq
