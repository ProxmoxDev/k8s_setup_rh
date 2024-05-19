#!/bin/bash
REPO_KUBERNETES_VERSION=1.29.0-150500.1.1

## Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

## kubectl
dnf install -y \
  kubectl-${REPO_KUBERNETES_VERSION}