#!/usr/bin/env bash
# ./incident/mark.sh "grafana: StorefrontErrorRateHigh firing"
cd "$(dirname "$0")"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a timeline.log
