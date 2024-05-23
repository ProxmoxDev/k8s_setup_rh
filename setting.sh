#!/bin/bash

NIC=ens18
PRIVATE_IP=
GATEWAY_IP=192.168.100.1

## hosts
cat >> /etc/hosts <<EOF
192.168.100.200 haproxy-01
192.168.100.210 controlplane-01
192.168.100.211 controlplane-02
192.168.100.212 controlplane-03
192.168.100.220 dataplane-01
192.168.100.221 dataplane-02
192.168.100.222 dataplane-03
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
