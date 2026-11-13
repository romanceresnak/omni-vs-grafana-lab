# source this file in every new CloudShell session:   source env.sh
export REGION="${REGION:-eu-west-1}"
export CLUSTER="${CLUSTER:-omni-lab}"
export LOG_GROUP="${LOG_GROUP:-/omni-lab/shop}"
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export PATH="$HOME/bin:$PATH"
if [ -z "${MY_IP:-}" ] && [ -f "$HOME/.omni-lab-ip" ]; then export MY_IP="$(cat "$HOME/.omni-lab-ip")"; fi
echo "REGION=$REGION CLUSTER=$CLUSTER ACCOUNT_ID=$ACCOUNT_ID LOG_GROUP=$LOG_GROUP MY_IP=${MY_IP:-<not set>}"
