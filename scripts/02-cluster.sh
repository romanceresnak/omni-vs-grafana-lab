#!/usr/bin/env bash
# Creates the EKS cluster (~15-20 min) and the IAM role for the collector (IRSA).
set -euo pipefail
: "${REGION:?run: source env.sh}"
# newest EKS version in standard support (CloudShell's kubectl is always recent)
VERSION=$(aws eks describe-cluster-versions --region "$REGION" \
  --query "clusterVersions[?versionStatus=='STANDARD_SUPPORT'].clusterVersion" --output text \
  | tr '\t' '\n' | sort -V | tail -1)
echo "Creating EKS ${VERSION:-default} cluster $CLUSTER in $REGION"
eksctl create cluster \
  --name "$CLUSTER" --region "$REGION" ${VERSION:+--version "$VERSION"} \
  --managed --nodegroup-name lab --node-type t3.large --nodes 2 \
  --with-oidc
kubectl apply -f k8s/00-namespaces.yaml
# The collector signs requests to the CloudWatch OTLP endpoints with these credentials.
eksctl create iamserviceaccount \
  --cluster "$CLUSTER" --region "$REGION" \
  --namespace observability --name otel-collector \
  --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --attach-policy-arn arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess \
  --override-existing-serviceaccounts --approve
kubectl get nodes
