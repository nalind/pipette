#!/bin/bash
set -ex
export STORAGE_DRIVER=vfs
mkdir -p /buildoutput/list
buildah create manifest list
for manifest in /buildoutput/*/image/manifest.json ; do
	buildah manifest add list dir:$(dirname ${manifest})
done
buildah manifest push --all list dir:/buildoutput/list/
