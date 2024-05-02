#!/bin/bash

NIC=ens18
PRIVATE_IP=
GATEWAY_IP=192.168.100.1

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
