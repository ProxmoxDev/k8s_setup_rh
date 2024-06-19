#!/bin/bash


## Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

## Get initial password
argocd admin initial-password -n argocd

## Port Forwarding
kubectl port-forward svc/argocd-server -n argocd 3000:443
