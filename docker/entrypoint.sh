#!/usr/bin/env bash
set -Eeuo pipefail

# Loads the user-owned, read-only environment file when mounted.
source /usr/local/lib/clawvm/load-env.sh

start_script="${HOME}/config/start.sh"

if [[ -x "${start_script}" ]]; then
    exec "${start_script}"
fi

exec sleep infinity