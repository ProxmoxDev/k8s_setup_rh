HA_PROXY_SERVER=192.168.100.
CONTROL_PLANE_IPS=( 192.168.100. 192.168.100. )

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
  server k8s-api-1 ${CONTROL_PLANE_IPS[0]}:6443
EOF

systemctl enable --now haproxy