#!/bin/bash

VERSION=v2.11.2

curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm -rf argocd-linux-amd64
