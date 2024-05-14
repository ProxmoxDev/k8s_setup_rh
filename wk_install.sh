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
  container-selinux \
  cri-o-${REPO_KUBERNETES_VERSION} \
  kubelet-${REPO_KUBERNETES_VERSION} \
  kubeadm-${REPO_KUBERNETES_VERSION}\
  kubectl-${REPO_KUBERNETES_VERSION}

systemctl enable --now crio.service
systemctl enable kubelet.service
