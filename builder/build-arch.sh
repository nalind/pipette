#!/bin/bash
set -ex

workdir=$(mktemp -d)
trap 'rm -fr ${workdir}' EXIT

for arch in ${ARCH:-aarch64 ppc64le s390x x86_64} ; do
	uuid=$(uuidgen)

	# What Fedora calls an architecture, and the naming suffix for the qemu
	# binary that'll emulate it, aren't always the same.  Map from the name
	# Fedora uses for it to the name qemu uses for it.
	fedoraarch=${arch}
	case ${fedoraarch} in
		ppc64le) qemuarch=ppc64 ;;
		*) qemuarch=${fedoraarch} ;;
	esac

	buildcontext=${BUILDCONTEXT:-/buildcontext}
	buildoutput=${BUILDOUTPUT:-/buildoutput}
	dockerfile=${DOCKERFILE:-${buildcontext}/Dockerfile}

	# Build the data for the cloud-init NoCloud provider.
	mkdir -p ${workdir}/cloud-init ${buildcontext} ${buildoutput}/${arch}

	tee ${workdir}/cloud-init/meta-data <<- EOF
	instance-id: ${uuid}-${fedoraarch}
	local-host-name: ${uuid}-${fedoraarch}
	EOF

	tee ${workdir}/cloud-init/user-data <<- EOF
	#cloud-config
	password: cloud
	chpasswd: { expire: false }
	runcmd:
	  - [ setenforce, 0 ]
	  - [ mkdir, -p, /buildcontext, /buildoutput ]
	  - [ mount, -t, 9p, -o, trans=virtio, context, /buildcontext ]
	  - [ mount, -t, 9p, -o, trans=virtio, output,  /buildoutput ]
	  - [ dnf, -v, -y, install, buildah ]
	  - [ buildah, build-using-dockerfile, --layers, -t, dir:/buildoutput/image, --logfile, /buildoutput/build.log, -f, ${dockerfile}, /buildcontext ]
	  - [ cp, /var/log/cloud-init.log, /var/log/cloud-init-output.log, /buildoutput ]
	  - [ /sbin/poweroff ]
	EOF

	# Build the ISO image containing the cloud-init data.
	iso=${workdir}/cloud-init.iso
	mkisofs -o ${iso} -input-charset default -volid cidata -J -r ${workdir}/cloud-init

	# For some architectures, we need to pass additional flags to qemu to
	# ensure that we have a PCI bus, which we need in order to be able to
	# use virtio.
	case ${qemuarch} in
		aarch64) machineargs="--machine virt,gic-version=2,pflash0=edk-efi -drive file=/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw,node-name=edk-efi,read-only=on,index=1 -cpu max";;
		s390x) machineargs="-cpu qemu,zpci=on";;
		*) machineargs="" ;;
	esac

	# Start the VM.  The cloud-init script tells it to stop when it's done.
	qemu-system-${qemuarch} -m 2048 ${machineargs} -smp sockets=2,cores=2 \
		-device virtio-9p-pci,fsdev=output,mount_tag=output \
		-fsdev local,path=${buildoutput}/${arch},id=output,security_model=none \
		-device virtio-9p-pci,fsdev=context,mount_tag=context \
		-fsdev local,path=${buildcontext},id=context,security_model=none,readonly \
		-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
		-usb -uuid ${uuid} -rtc base=utc -msg timestamp=on \
		-hda /Fedora-Cloud-Base-32-1.6.${fedoraarch}.qcow2 -cdrom ${iso} -display none
done
