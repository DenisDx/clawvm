#!/usr/bin/env bash
set -Eeuo pipefail

start_script="${HOME}/config/start.sh"

if [[ -x "${start_script}" ]]; then
    exec "${start_script}"
fi

exec sleep infinity