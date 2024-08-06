#!/bin/bash

aws eks update-kubeconfig --region eu-west-2 --name dev-eksCluster --profile pocawsadmin
kubectl get nodes
export GITHUB_TOKEN=""
flux bootstrap github \
    --token-auth \
    --owner=katkampradeep \
    --repository=FluxCd \
    --path=eksrepo \
    --personal \
    --branch poc-08072024
mkdir -p clusters/prometheus
cd clusters
cat >prometheusNs.yaml<<EOF
apiVersion: v1 
kind: Namespace 
metadata: 
  name: prometheus
EOF

cat >prometheus-git-config.yaml<<EOF
apiVersion: source.toolkit.fluxcd.io/v1beta2 
kind: GitRepository 
metadata: 
  name: prometheus-config 
  namespace: prometheus
spec: 
  interval: 1m 
  url: https://github.com/my-github-username/my-repository-name 
  ref: 
    branch: main 
    path: clusters/prometheus
EOF