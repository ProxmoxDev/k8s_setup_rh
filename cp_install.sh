#!/bin/bash
#special thanks https://gist.github.com/inductor/32116c486095e5dde886b55ff6e568c8

KUBE_API_SERVER_IP=192.168.100.
KUBERNETES_VERSION=v1.29
MANIFEST_VERSION=1.29.0
REPO_CRIO_PATH=stable:/${KUBERNETES_VERSION}
REPO_KUBERNETES_VERSION=1.29.0-150500.1.1

## デフォルトで入ってるコンテナパッケージを削除
dnf remove -y containers-common

## swap無効
swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab

## Firewalld無効
systemctl disable --now firewalld

## ネットワーク設定
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1

## container
## https://github.com/cri-o/packaging

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF

cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/$REPO_CRIO_PATH/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/$REPO_CRIO_PATH/rpm/repodata/repomd.xml.key
EOF

dnf install -y \
  dnf install -y nfs-utils-1:2.5.4-25.el9.x86_64 \
  container-selinux \
  cri-o-${REPO_KUBERNETES_VERSION} \
  kubelet-${REPO_KUBERNETES_VERSION} \
  kubeadm-${REPO_KUBERNETES_VERSION}\
  kubectl-${REPO_KUBERNETES_VERSION}

systemctl enable --now crio.service
systemctl enable kubelet.service

## kubeadm設定
# Set kubeadm bootstrap token using openssl
KUBEADM_BOOTSTRAP_TOKEN=$(openssl rand -hex 3).$(openssl rand -hex 8)

# Set init configuration for the first control plane
cat > ~/init_kubeadm.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
bootstrapTokens:
- token: "$KUBEADM_BOOTSTRAP_TOKEN"
  description: "kubeadm bootstrap token"
  ttl: "24h"
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  serviceSubnet: "192.168.100.0/24"
  podSubnet: "192.128.100.0/24"
kubernetesVersion: "${MANIFEST_VERSION}"
controlPlaneEndpoint: "${KUBE_API_SERVER_IP}:6443"
EOF

kubeadm init --config ~/init_kubeadm.yaml

# kubectl Setting
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "source <(kubectl completion bash)" >> ~/.bashrc
alias k=kubectl
complete -F __start_kubectl k

# Generate control plane certificate
KUBEADM_UPLOADED_CERTS=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)

# Set join configuration for other control plane nodes
cat > ~/join_kubeadm_cp.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
discovery:
  bootstrapToken:
    apiServerEndpoint: "${KUBE_API_SERVER_IP}:6443"
    token: "$KUBEADM_BOOTSTRAP_TOKEN"
    unsafeSkipCAVerification: true
controlPlane:
  certificateKey: "$KUBEADM_UPLOADED_CERTS"
EOF

# Set join configuration for worker nodes
cat > ~/join_kubeadm_wk.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
nodeRegistration:
  criSocket: "unix:///var/run/crio/crio.sock"
discovery:
  bootstrapToken:
    apiServerEndpoint: "${KUBE_API_SERVER_IP}:6443"
    token: "$KUBEADM_BOOTSTRAP_TOKEN"
    unsafeSkipCAVerification: true
EOF
