#!/usr/bin/env bash

env_file="${HOME}/.env"

if [[ -r "${env_file}" ]]; then
    readonly deployment_env_names=(
        CLAWVM_HTTPS_HOST
        CLAWVM_HTTPS_PORT
        OPENCLAW_GATEWAY_PORT
    )
    declare -A deployment_env_values=()

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
fi