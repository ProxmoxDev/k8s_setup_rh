#!/bin/bash

SHARE_DIRECTORY=/export/nfs
PV_DIRECTORYS=50
SHARE_ADDRESS=192.168.100.0/24

dnf install -y nfs-utils-1:2.5.4-25.el9.x86_64
mkdir -p ${SHARE_DIRECTORY}

i=1;i_max=$PV_DIRECTORYS; while [ "$i" -le "$i_max" ]; do j=$(printf "%04d" $i); sudo mkdir /export/nfs/pv$j ; i=$(($i+1)) ; done

firewall-cmd --permanent --zone=public --add-service=nfs
firewall-cmd --reload

cat <<EOF > /etc/exports
${SHARE_DIRECTORY} ${SHARE_ADDRESS}(rw,no_root_squash)
EOF

systemctl enable --now nfs-server
