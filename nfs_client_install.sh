#!/bin/bash

NFS_SERVER_IP=192.168.100.
NFS_SERVER_DIR=
SHARE_DIRECTORY=

dnf install -y nfs-utils-1:2.5.4-25.el9.x86_64

mkdir ${SHARE_DIRECTORY}

cat <<EOF >> /etc/fstab
${NFS_SERVER_IP}:${NFS_SERVER_DIR} ${SHARE_DIRECTORY} nfs defaults 0 0
EOF

reboot