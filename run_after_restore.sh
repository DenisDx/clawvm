#!/usr/bin/env bash
# Restore ClawVM portable data ownership, modes, and optional workspace ACLs.
set -Eeuo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly script_dir
readonly data_dir="${script_dir}/data"
readonly workspace_dir="${data_dir}/.openclaw/workspace"
readonly clawvm_uid=1000
readonly clawvm_gid=1000

require_root() {
    if (( EUID != 0 )); then
        printf 'Run this script with sudo: sudo %q\n' "$0" >&2
        exit 1
    fi
}

require_data_directory() {
    if [[ -L "${data_dir}" || ! -d "${data_dir}" ]]; then
        printf 'Expected a real data directory at %s\n' "${data_dir}" >&2
        exit 1
    fi
}

restore_owner_and_modes() {
    chown --recursive "${clawvm_uid}:${clawvm_gid}" "${data_dir}"
    find "${data_dir}" -xdev -type d -exec chmod 0750 {} +
    find "${data_dir}" -xdev -type f -exec chmod 0640 {} +
    find "${data_dir}" -xdev -type f -perm /0111 -exec chmod 0750 {} +
}

restore_runtime_files() {
    local startup_script="${data_dir}/config/start.sh"
    local environment_file="${data_dir}/.env"

    if [[ -f "${startup_script}" ]]; then
        chmod 0750 "${startup_script}"
    fi
    if [[ -f "${environment_file}" ]]; then
        chmod 0600 "${environment_file}"
    fi
}

restore_workspace_acl() {
    if [[ ! -d "${workspace_dir}" ]]; then
        return
    fi

    chmod 2770 "${workspace_dir}"
    if ! getent group clawvm-share >/dev/null; then
        printf 'Workspace group clawvm-share does not exist; restored owner and mode only.\n' >&2
        return
    fi

    chgrp clawvm-share "${workspace_dir}"
    setfacl -m u:1000:rwx,g:clawvm-share:rwx,m::rwx,o::--- "${workspace_dir}"
    setfacl -d -m u::rwx,u:1000:rwx,g::rwx,g:clawvm-share:rwx,m::rwx,o::--- "${workspace_dir}"
}

main() {
    require_root
    require_data_directory
    restore_owner_and_modes
    restore_runtime_files
    restore_workspace_acl
    printf 'Restored ClawVM data permissions at %s\n' "${data_dir}"
}

main "$@"