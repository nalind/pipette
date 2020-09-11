#!/bin/bash
set -ex
tmpdir=$(mktemp -d)
trap 'rm -fr ${tmpdir}' EXIT

uuid=$(uuidgen)

# for arch in aarch64 s390x x86_64; do
for arch in aarch64 ; do
	fedoraarch=${arch}
	qemuarch=${arch}
	buildcontext=${1:-$(pwd)}
	buildoutput=${2:-/tmp/virt-image}/${fedoraarch}
	dockerfile=${3:-Dockerfile}
	iso=${tmpdir}/cloud-init.iso
	machineargs=
	case ${qemuarch} in
		aarch64) machineargs="--machine raspi3 -object rng-random,id=urandom";;
		*) machineargs="-object rng-random,id=urandom";;
	esac

	mkdir -p ${tmpdir}/cloud-init ${tmpdir}/${fedoraarch} ${buildoutput}

	tee ${tmpdir}/cloud-init/meta-data <<- EOF
	instance-id: ${uuid}-${fedoraarch}
	local-host-name: ${uuid}-${fedoraarch}
	EOF

	tee ${tmpdir}/cloud-init/user-data <<- EOF
	#cloud-config
	password: cloud
	chpasswd: { expire: false }
	runcmd:
	  - [ mkdir, -p, /buildcontext, /buildoutput ]
	  - [ mount, -t, 9p, -o, trans=virtio, buildcontext, /buildcontext ]
	  - [ mount, -t, 9p, -o, trans=virtio, buildoutput,  /buildoutput ]
	  - [ mount ]
	  - [ dnf, -v, -y, install, buildah ]
	  - [ buildah, build-using-dockerfile, --layers, -t, dir:/buildoutput/image, --logfile, /buildoutput/build.log -f, ${dockerfile}, /buildcontext ]
	  - [ /sbin/poweroff ]
	EOF

	mkisofs -o ${iso} -input-charset default -volid cidata -J -r ${tmpdir}/cloud-init

	qemu-system-${qemuarch} -m 1024 ${machineargs} -snapshot \
		-device virtio-9p-pci,fsdev=output,mount_tag=mount_tag \
		-fsdev local,path=${buildoutput},id=output,security_model=none \
		-device virtio-9p-pci,fsdev=context,mount_tag=mount_tag \
		-fsdev local,path=${buildcontext},id=context,security_model=none,readonly \
		-hda /var/lib/libvirt/images/iso/Fedora-Cloud-Base-32-1.6.${fedoraarch}.qcow2 -cdrom ${iso}
	skopeo inspect --config dir:${buildoutput}/image | jq
done
