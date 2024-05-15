#!/bin/bash

SHARE_DIRECTORY=/nfs
SHARE_ADDRESS=192.168.100.0/24

dnf install -y nfs-utils-1:2.5.4-25.el9.x86_64
mkdir ${SHARE_DIRECTORY}

firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --reload

cat <<EOF > /etc/exports
${SHARE_DIRECTORY} ${SHARE_ADDRESS}(rw,no_root_squash)
EOF

systemctl enable --now nfs-server