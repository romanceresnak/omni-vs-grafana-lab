#!/usr/bin/env python3
"""Replace ${REGION} ${CLUSTER} ${ACCOUNT_ID} ${LOG_GROUP} ${MY_IP} in a file and print it.
Only these names are touched, so Grafana/Prometheus templates stay intact."""
import os, re, sys
NAMES = ["REGION", "CLUSTER", "ACCOUNT_ID", "LOG_GROUP", "MY_IP"]
text = open(sys.argv[1]).read()
for n in NAMES:
    if "${" + n + "}" in text:
        v = os.environ.get(n)
        if not v:
            sys.exit(f"render.py: {n} is not set (did you run 'source env.sh'?)")
        text = text.replace("${" + n + "}", v)
sys.stdout.write(text)
