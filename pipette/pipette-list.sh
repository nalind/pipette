#!/bin/bash
set -ex
export STORAGE_DRIVER=vfs
mkdir -p ${BUILDOUTPUT:-/buildoutput}/list
buildah manifest create list
for manifest in ${BUILDOUTPUT:-/buildoutput}/*/image/manifest.json ; do
	buildah manifest add list dir:$(dirname ${manifest})
done
buildah manifest push --all list dir:${BUILDOUTPUT:-/buildoutput}/list/
