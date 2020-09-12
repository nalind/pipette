#!/bin/bash
set -ex
tmpdir=$(mktemp -d)
trap 'rm -fr ${tmpdir}' EXIT

uuid=$(uuidgen)

# for arch in aarch64 ppc64le s390x x86_64; do
for arch in x86_64   ; do
	fedoraarch=${arch}
	case ${fedoraarch} in
		ppc64le) qemuarch=ppc64 ;;
		*) qemuarch=${fedoraarch} ;;
	esac
	buildcontext=${1:-$(pwd)}
	buildoutput=${2:-/tmp/virt-image}/${fedoraarch}
	dockerfile=${3:-Dockerfile}
	iso=${tmpdir}/cloud-init.iso
	machineargs=
	case ${qemuarch} in
		aarch64) machineargs="--machine virt,gic-version=2,pflash0=edk-efi -drive file=/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw,node-name=edk-efi,read-only=on,index=1 -cpu max";;
		s390x) machineargs="-cpu qemu,zpci=on";;
		*) machineargs="" ;;
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
	  - [ setenforce, 0 ]
	  - [ mkdir, -p, /buildcontext, /buildoutput/${arch} ]
	  - [ mount, -t, 9p, -o, trans=virtio, context, /buildcontext ]
	  - [ mount, -t, 9p, -o, trans=virtio, output,  /buildoutput ]
	  - [ mount ]
	  - [ dnf, -v, -y, install, buildah ]
	  - [ buildah, build-using-dockerfile, --layers, -t, dir:/buildoutput/image, --logfile, /buildoutput/build.log, -f, ${dockerfile}, /buildcontext ]
	  - [ /sbin/poweroff ]
	EOF

	mkisofs -o ${iso} -input-charset default -volid cidata -J -r ${tmpdir}/cloud-init

	qemu-system-${qemuarch} -m 1536 ${machineargs} -smp sockets=2,cores=2 -snapshot \
		-device virtio-9p-pci,fsdev=output,mount_tag=output \
		-fsdev local,path=${buildoutput},id=output,security_model=none \
		-device virtio-9p-pci,fsdev=context,mount_tag=context \
		-fsdev local,path=${buildcontext},id=context,security_model=none,readonly \
		-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
		-usb -uuid ${uuid} -rtc base=utc -msg timestamp=on \
		-hda /var/lib/libvirt/images/iso/Fedora-Cloud-Base-32-1.6.${fedoraarch}.qcow2 -cdrom ${iso}

	skopeo inspect --config dir:${buildoutput}/image | jq
done
