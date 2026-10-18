#!/usr/bin/env bash
# Initialize the persistent document venv offline from the image's wheel bundle.
set -Eeuo pipefail
trap 'printf "Document environment initialization failed at line %s\n" "$LINENO" >&2' ERR

bundle=/opt/document-tools
root="${HOME}/.local/share/document-tools"
version="$(cat "${bundle}/SHA256SUMS"; python3 --version)"
version="$(printf '%s' "${version}" | sha256sum)"
version="${version%% *}"
target="${root}/venvs/${version}"

mkdir -p "${root}/venvs"
exec 9>"${root}/.install.lock"
flock 9

if [[ -e "${root}/venv" && ! -L "${root}/venv" ]]; then
    printf 'Refusing to replace non-symlink document environment: %s\n' "${root}/venv" >&2
    exit 1
fi

if [[ ! -f "${target}/.ready" ]]; then
    printf 'Initializing document environment from bundled wheels: %s\n' "${target}" >&2
    (cd "${bundle}" && sha256sum --check --status SHA256SUMS)
    python3 -m venv "${target}"
    "${target}/bin/python" -m pip --isolated install \
        --no-index --no-cache-dir --no-deps \
        --find-links "${bundle}/wheels" \
        -r "${bundle}/requirements.txt" >&2
    "${target}/bin/python" -m pip --isolated check >&2
    "${target}/bin/python" -c 'import fitz, pdfplumber, pypdf, docx, openpyxl, bs4, PIL, lxml'
    touch "${target}/.ready"
fi

if [[ ! -L "${root}/venv" || "$(readlink "${root}/venv")" != "${target}" ]]; then
    link="${root}/.venv-$$"
    trap 'rm -f -- "${link}"' EXIT
    ln -s "${target}" "${link}"
    mv -Tf "${link}" "${root}/venv"
fi
