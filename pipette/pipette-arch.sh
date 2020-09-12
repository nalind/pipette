#!/bin/bash
set -ex
workdir=/tmp/workdir

uuid=$(uuidgen)

for arch in ${ARCH:-aarch64 ppc64le x86_64} ; do
	fedoraarch=${arch}
	case ${fedoraarch} in
		ppc64le) qemuarch=ppc64 ;;
		*) qemuarch=${fedoraarch} ;;
	esac
	buildcontext=/buildcontext
	buildoutput=/buildoutput/${arch}
	dockerfile=${DOCKERFILE:-Dockerfile}
	iso=${tmpdir}/cloud-init.iso
	case ${qemuarch} in
		aarch64) machineargs="--machine virt,gic-version=max,pflash0=edk-efi -drive file=/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw,node-name=edk-efi,read-only=on,index=1 -cpu max";;
		*) machineargs="" ;;
	esac

	mkdir -p ${workdir}/cloud-init ${buildoutput}/${fedoraarch}

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
	  - [ mkdir, -p, /buildcontext, /buildoutput/${arch} ]
	  - [ mount, -t, 9p, -o, trans=virtio, context, /buildcontext ]
	  - [ mount, -t, 9p, -o, trans=virtio, output,  /buildoutput ]
	  - [ mount ]
	  - [ dnf, -v, -y, install, buildah ]
	  - [ buildah, build-using-dockerfile, --layers, -t, dir:/buildoutput/image, --logfile, /buildoutput/build.log, -f, ${dockerfile}, /buildcontext ]
	  - [ cp, /var/log/cloud-init.log, /var/log/cloud-init-output.log, /buildoutput ]
	  - [ /sbin/poweroff ]
	EOF

	mkisofs -o ${iso} -input-charset default -volid cidata -J -r ${workdir}/cloud-init

	qemu-system-${qemuarch} -m 1536 ${machineargs} -smp sockets=2,cores=2 \
		-device virtio-9p-device,fsdev=output,mount_tag=output \
		-fsdev local,path=${buildoutput},id=output,security_model=none \
		-device virtio-9p-device,fsdev=context,mount_tag=context \
		-fsdev local,path=${buildcontext},id=context,security_model=none,readonly \
		-sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
		-device virtio-rng-pci -uuid ${uuid} -rtc base=utc -msg timestamp=on \
		-hda /Fedora-Cloud-Base-32-1.6.${fedoraarch}.qcow2 -cdrom ${iso} -display none
done
buildah create manifest list
for manifest in /buildoutput/*/image/manifest.json ; do
	buildah manifest add list dir:$(dirname ${manifest})
done
buildah manifest push --all list dir:/buildoutput/list/
