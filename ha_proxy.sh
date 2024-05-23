HA_PROXY_SERVER=dev-lb-01
CONTROL_PLANE_IPS=( dev-master-01 dev-master-02 dev-master-03 )

dnf install -y haproxy-2.4.22-3.el9_3.x86_64

cat > /etc/haproxy/haproxy.cfg <<EOF
frontend k8s-api
  bind ${HA_PROXY_SERVER}:6443
  mode tcp
  option tcplog
  default_backend k8s-api
backend k8s-api
  mode tcp
  balance roundrobin
  server dev-master-01 ${CONTROL_PLANE_IPS[0]}:6443
  server dev-master-02 ${CONTROL_PLANE_IPS[1]}:6443
  server dev-master-03 ${CONTROL_PLANE_IPS[2]}:6443
EOF

# firewall-cmd --zone=public --add-port=6443/tcp --add-port=10250/tcp --permanent
# firewall-cmd --reload

systemctl disable --now firewalld
systemctl enable --now haproxy
