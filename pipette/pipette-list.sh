#!/bin/bash
set -ex
export STORAGE_DRIVER=vfs
mkdir -p /buildoutput/list
buildah manifest create list
for manifest in /buildoutput/*/image/manifest.json ; do
	buildah manifest add list dir:$(dirname ${manifest})
done
buildah manifest push --all list dir:/buildoutput/list/
