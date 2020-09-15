#!/bin/bash
set -ex
export STORAGE_DRIVER=vfs
buildoutput="${BUILDOUTPUT:-/buildoutput}"
buildah manifest create list
for manifest in "${buildoutput}"/*/image/manifest.json ; do
	if test -s "${manifest}" ; then
		buildah manifest add list dir:"$(dirname ${manifest})"
	fi
done
mkdir -p "${buildoutput}"/list
buildah manifest push --all list dir:"${buildoutput}"/list/
