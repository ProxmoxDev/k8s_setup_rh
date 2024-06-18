#!/bin/bash

NIC=ens18
PRIVATE_IP=
GATEWAY_IP=192.168.100.1

## date
timedatectl set-timezone  Asia/Tokyo
dnf remove -y ntp*
dnf install -y chrony
echo '#Add TimeSync' >> /etc/chrony.conf
echo 'server time.aws.com prefer iburst' >> /etc/chrony.conf
systemctl enable --now chronyd

## hosts
cat >> /etc/hosts <<EOF
192.168.100.110 dev-code-01
192.168.100.200 dev-lb-01
192.168.100.210 dev-master-01
192.168.100.211 dev-master-02
192.168.100.212 dev-master-03
192.168.100.220 dev-node-01
192.168.100.221 dev-node-02
192.168.100.222 dev-node-03
192.168.100.230 dev-nfs-01
EOF

## SELinux無効
sed -i -e 's/^\SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

## ネットワーク設定
nmcli con mod $NIC ipv4.addresses "$PRIVATE_IP"
nmcli con mod $NIC ipv4.gateway "$GATEWAY_IP"
nmcli con mod $NIC ipv4.method manual
nmcli con mod $NIC ipv4.dns "8.8.8.8 1.1.1.1"
nmcli con down $NIC ; nmcli con up $NIC

## Reboot
reboot
