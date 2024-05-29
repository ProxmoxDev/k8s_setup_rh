#!/bin/bash
#special thanks https://gist.github.com/inductor/32116c486095e5dde886b55ff6e568c8

KUBE_API_SERVER_IP=dev-lb-01
KUBERNETES_VERSION=v1.28
MANIFEST_VERSION=1.28.10
REPO_CRIO_PATH=stable:/${KUBERNETES_VERSION}
REPO_KUBERNETES_VERSION=1.28.10-150500.1.1
# REPO_KUBERNETES_VERSION=1.30.1-150500.1.1

## デフォルトで入ってるコンテナパッケージを削除
dnf remove -y containers-common

## swap無効
swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab

## Firewalld無効
systemctl disable --now firewalld

## ネットワーク設定
### https://kubernetes.io/ja/docs/setup/production-environment/container-runtimes/#ipv4%E3%83%95%E3%82%A9%E3%83%AF%E3%83%BC%E3%83%87%E3%82%A3%E3%83%B3%E3%82%B0%E3%82%92%E6%9C%89%E5%8A%B9%E5%8C%96%E3%81%97-iptables%E3%81%8B%E3%82%89%E3%83%96%E3%83%AA%E3%83%83%E3%82%B8%E3%81%95%E3%82%8C%E3%81%9F%E3%83%88%E3%83%A9%E3%83%95%E3%82%A3%E3%83%83%E3%82%AF%E3%82%92%E8%A6%8B%E3%81%88%E3%82%8B%E3%82%88%E3%81%86%E3%81%AB%E3%81%99%E3%82%8B
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe br_netfilter
modprobe overlay

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

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
  nfs-utils-1:2.5.4-25.el9.x86_64 \
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
  podSubnet: "10.244.0.0/16"
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
