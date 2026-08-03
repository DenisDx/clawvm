#!/usr/bin/env bash

# Load the user-owned environment file without overriding deployment values.
load_clawvm_env() {
    local env_file="${HOME}/.env"
    local env_name
    local -a deployment_env_names=(
        CLAWVM_HTTPS_HOST
        CLAWVM_HTTPS_PORT
        OPENCLAW_GATEWAY_PORT
    )
    local -A deployment_env_values=()

    if [[ ! -r "${env_file}" ]]; then
        return
    fi

    for env_name in "${deployment_env_names[@]}"; do
        if [[ -v "${env_name}" ]]; then
            deployment_env_values["${env_name}"]="${!env_name}"
        fi
    done

    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a

    for env_name in "${!deployment_env_values[@]}"; do
        export "${env_name}=${deployment_env_values[${env_name}]}"
    done
}

load_clawvm_env
unset -f load_clawvm_env