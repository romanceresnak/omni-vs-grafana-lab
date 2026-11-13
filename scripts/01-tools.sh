#!/usr/bin/env bash
# Installs eksctl into ~/bin (persists in CloudShell). kubectl is already in CloudShell.
set -euo pipefail
mkdir -p "$HOME/bin"
ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && ARCH=amd64; [ "$ARCH" = "aarch64" ] && ARCH=arm64
curl -sSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH}.tar.gz" | tar xz -C "$HOME/bin"
export PATH="$HOME/bin:$PATH"
echo "eksctl  $(eksctl version)"
echo "kubectl $(kubectl version --client -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["clientVersion"]["gitVersion"])')"
echo "aws     $(aws --version)"
