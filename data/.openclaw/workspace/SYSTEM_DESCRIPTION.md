# ClawVM System Description

This is the shared runtime reference for ClawVM-derived virtual machines.
Read this machine's local [AGENTS.md](AGENTS.md), when configured, for agent
identity, mounts, permissions, and task-specific restrictions. That file is
private to the deployment, ignored by Git, and not supplied by this distribution.
This shared reference is the distributed source for software usage and common
VM behavior, independent of any particular agent profile. **Agents working
inside the VM must not edit this file.** Report omissions to the image
maintainer instead.

This file is version-controlled and must remain identical across forks using
the same read-only software baseline. Fork-specific UIDs, host paths, published
ports, account settings, and manually installed OpenClaw versions do not belong
here. Its source of truth is the image
[Dockerfile](../../../Dockerfile) and
[Python dependency manifest](../../../docker/document-requirements.txt).
Those source links work in the repository checkout, not necessarily inside
the VM; the complete source repository is not mounted by default.

The inventory covers every explicitly selected Debian package, the extra
command-line programs supplied by their dependencies, the browser installation,
the Python document environment, and image launchers. It distinguishes programs
from support data/libraries and from wrappers without a usable backing program.
Some explicitly selected utilities are also present in the Node base image.
Package upgrades may change versions: query the installed program rather than
assuming a version from this document.

## Runtime, storage, and permissions

- Base: Debian Bookworm with Node.js 24, on Linux amd64. Check `cat
  /etc/os-release`, `uname -m`, `node --version`, and `python3 --version`.
- Run as unprivileged user `clawvm`; use `id` to discover this fork's UID/GID.
  There is no general sudo access.
- Home is `/home/clawvm`, a persistent writable host mount. The workspace is
  `/home/clawvm/.openclaw/workspace`. Extra nested mounts and their permissions
  are deployment-specific; do not assume that everything below home is writable.
- Keep work and final artifacts below home. State/configuration locations:

  | Location | Purpose |
  | --- | --- |
  | `~/.openclaw` | OpenClaw installation, configuration, and private state. |
  | `~/config/start.sh` | Optional user-owned startup script. |
  | `~/config/Caddyfile` | Deployment's Caddy reverse-proxy configuration. |
  | `~/.local/bin` | User-local command directory on PATH. |
  | `~/.cache` | Persistent user caches (`XDG_CACHE_HOME`). |
  | `~/.config` | User configuration (`XDG_CONFIG_HOME`). |
  | `~/.local/share` | User data (`XDG_DATA_HOME`), including the document venv. |
  | `~/.local/share/caddy` | Private Caddy state and internal certificate authority. |

- Root filesystem is read-only. Do not run `apt install`, `apt upgrade`,
  global `pip`/`npm` installs, or write to `/usr`, `/etc`, `/opt`, or
  `/ms-playwright`. Request an image update for missing system dependencies.
- `/tmp` and `/run` are ephemeral tmpfs, normally limited to 64 MiB and 16 MiB
  and mounted `noexec`. Shared memory is normally 1 GiB. Check actual mounts
  with `findmnt` and available space with `df -h "$HOME" /tmp /dev/shm`.
- For large conversions, create a task-specific temporary directory under
  home and set `TMPDIR` to it. Native extensions and executable temporary
  artifacts need an executable filesystem; do not weaken mount permissions.
- Inspect ACLs and ownership rather than changing them to bypass a denied
  write. Host ACLs and machine-specific instructions are authoritative.

## Invocation conventions

Examples below run **inside the VM**, not on the host. Filenames, hosts, users,
and database names are placeholders. Use copies of input documents and separate
output filenames. Network connections, uploads, email, database changes,
permission changes, and destructive operations require task authorization.

Use `command -v NAME` to locate a command and `NAME --help` where supported
for its detailed syntax. `dpkg-query -L PACKAGE` lists installed package files;
`dpkg-query -W PACKAGE` reports its version. Presence alone does not grant
permission or mean a privileged operation will work.

## Development, shells, and text tools

| Package or installation | Purpose and invocation examples |
| --- | --- |
| Node base: `node`, `npm`, `npx`, Corepack | JavaScript: `node app.js`; local dependencies: `npm ci` in a writable checkout; `corepack --version`. `npx --version` checks the package runner; running a package may download and execute code. Corepack provides `yarn` and `pnpm` shims, but fetching a selected package-manager version may need network access. |
| `python3` | System Python: `python3 script.py` or `python3 --version`. Document libraries use `document-python`, not plain system Python. |
| `python3-pip` | `python3 -m pip --version`; `pip`, `pip3`, and `pip3.11` are entrypoints. Install user projects only into their own venv, not the externally managed system environment. |
| `python3-venv` | `python3 -m venv "$HOME/.venvs/project"`; then `"$HOME/.venvs/project/bin/python" script.py`. |
| `pipx` | Isolated Python CLI applications: `pipx list`; with approval, `pipx install PACKAGE` into user storage. |
| `python3-dev` | Extension build headers and flags: `python3-config --includes`; versioned and architecture-prefixed variants are listed below. |
| `gcc`, `g++`, `make`, `build-essential` | Build locally: `gcc hello.c -o hello`; `g++ hello.cpp -o hello`; `make -C project`. `build-essential` is a build-tool metapackage, not a command. |
| `pkg-config`, `libsqlite3-dev` | Development flags/SQLite headers: `pkg-config --cflags --libs sqlite3`. |
| `bash-completion` | Interactive Bash completion; press Tab in Bash. `bash --noprofile --norc script.sh` runs a shell script without interactive startup files. |
| `git` | `git status --short`; `git --no-pager diff`; commit/push only when authorized. |
| `ripgrep` | Text search: `rg -n 'pattern' directory`. |
| `fd-find` | File search: `fd '\.pdf$' directory`. The image supplies `fd` as an alias for Debian's `fdfind`. |
| `fzf` | Interactive selection: `printf '%s\n' first second \| fzf`; `fzf-tmux` embeds selection in tmux. Prefer deterministic commands for noninteractive agent work. |
| `jq` | JSON: `jq '.items[]' input.json`. |
| Go `yq` v4.45.4 | YAML: `yq '.services' compose.yml`; this is Mike Farah's implementation, not the Python wrapper. |
| `vim-tiny`, `vim-common` | Edit with `vi notes.txt` or `vim.tiny notes.txt`; `view notes.txt` is read-only mode and `ex` is line-oriented. **There is no `vim` command in the verified image.** This is a small Vim build, not full Vim/Neovim. |
| `nano` | `nano notes.txt`; `rnano` is its restricted mode. |
| `less` | Page text: `less -F report.txt`; for noninteractive output, prefer `sed -n '1,80p' report.txt`. |
| `file` | Identify input type before choosing a parser: `file input.bin`. |
| `tree` | Bounded directory listing: `tree -L 2 directory`. |
| `xxd` | Hexadecimal inspection: `xxd -l 64 input.bin`. It is a separate Debian package; `vim-common` alone does not provide it with recommends disabled. |
| `shellcheck` | Shell lint: `shellcheck script.sh`; use `-x` only when following sourced files is appropriate. |
| `yamllint` | YAML lint: `yamllint config.yaml`. |
| Base shell/text utilities | `sed -n '1,40p' file.txt`, `awk '{print $1}' file.txt`, `sort`, `uniq`, `cut`, `diff -u old.txt new.txt`, `find`, `head`, `tail`, `wc`, `sha256sum`, `timeout 30s COMMAND`. Bash supports pipes and redirects; quote paths. |

## PDF, OCR, graphics, and document conversion

| Package | Programs and invocation examples |
| --- | --- |
| `poppler-utils` | Inspect: `pdfinfo input.pdf`, `pdffonts input.pdf`, `pdfsig input.pdf`. Text: `pdftotext -layout input.pdf text.txt`; HTML: `pdftohtml -s input.pdf output.html`. |
| `poppler-utils` rendering | `pdftoppm -f 1 -l 1 -singlefile -r 150 -png input.pdf page`; `pdftocairo -png -singlefile input.pdf page`; `pdftops input.pdf output.ps`. |
| `poppler-utils` image/page/attachment tools | `pdfimages -png input.pdf image`; `pdfseparate input.pdf page-%d.pdf`; `pdfunite first.pdf second.pdf combined.pdf`; `pdfdetach -list input.pdf`; `pdfattach input.pdf attachment.txt attached.pdf` attaches a file to a new PDF. |
| `ghostscript` | Render/rewrite: `gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOutputFile=rewritten.pdf input.pdf`. Frontends include `ps2pdf input.ps output.pdf`, `pdf2ps input.pdf output.ps`, and `ps2ascii input.ps`. |
| `qpdf` | `qpdf --check input.pdf`; `qpdf --linearize input.pdf linearized.pdf`. Helpers `fix-qdf` and `zlib-flate` handle QDF repair and raw compression streams, not general PDF text extraction. |
| `tesseract-ocr` | `tesseract --list-langs`; `tesseract page.png stdout -l eng+rus+tha`. Input must be an image, not a PDF. Training utilities are installed but are not needed for normal OCR. |
| `tesseract-ocr-eng`, `tesseract-ocr-rus`, `tesseract-ocr-tha` | Preinstalled English, Russian, and Thai recognition data selected with `-l eng`, `-l rus`, or `-l tha`. `tesseract-ocr-osd` supplies orientation/script detection: `tesseract page.png stdout --psm 0`. |
| `pandoc` | Supported document formats: `pandoc input.docx -t markdown -o output.md`; `pandoc --list-input-formats`. It does not read arbitrary PDFs or guarantee complex Office layout fidelity. PDF output may need an engine not installed here; do not assume LaTeX is available. |
| `librsvg2-bin` | SVG rendering: `rsvg-convert input.svg -o output.png`. |
| Python image/document packages | Use `document-python`; see the import and usage table below. |

Prefer text extraction before OCR. For a scanned PDF, work on selected pages:

```bash
mkdir -p "$HOME/.cache"
work="$(mktemp -d "$HOME/.cache/pdf-work.XXXXXX")"
export TMPDIR="$work"
pdftoppm -f 1 -l 1 -singlefile -r 150 -png input.pdf "$work/page"
tesseract "$work/page.png" "$work/recognized" -l eng+rus+tha
cat "$work/recognized.txt"
```

Copy desired outputs into the workspace and remove only your own scratch
directory when finished. OCR may be inaccurate: inspect important extracted
values and tables. PDF rewriting can invalidate signatures or alter forms,
metadata, and other features. Preserve originals. LibreOffice, OCRmyPDF, and
ImageMagick are not part of this documented installation.

## Persistent Python document environment

`document-python` initializes and executes
`~/.local/share/document-tools/venv/bin/python`. The persistent `venv` is a
symlink into image-managed version directories. Startup or first invocation
installs the pinned wheels from `/opt/document-tools` **offline**, with an
installation lock and an atomic active-link switch. Initialization errors are
reported; do not ignore them or silently fall back to a different interpreter.

Do not use `pip --user` to recreate this environment or modify/delete its
version directories. Request a manifest/image update for permanent additions.
Use a separate personal venv for experiments. System Python remains separate.
To initialize then activate interactively:

```bash
document-python -c 'import pymupdf, pdfplumber, pypdf'
source ~/.local/share/document-tools/venv/bin/activate
python your_script.py
deactivate
```

Each expression below belongs inside a Python script run with
`document-python script.py` (or `document-python -c 'CODE'`).

| Installed distribution | Import and example use |
| --- | --- |
| `pymupdf` | `import pymupdf; doc = pymupdf.open("input.pdf"); print(doc[0].get_text()); doc.close()`; also renders pages with `page.get_pixmap()`. The legacy `fitz` import exists but is deprecated. |
| `pdfplumber` | `import pdfplumber`; use `with pdfplumber.open("input.pdf") as doc:` then `doc.pages[0].extract_text()` or `.extract_tables()`. |
| `pypdf` | `from pypdf import PdfReader, PdfWriter`; `print(PdfReader("input.pdf").pages[0].extract_text())`; `PdfWriter` supports page selection/combination. |
| `pillow` | `from PIL import Image`; `Image.open("input.png").convert("RGB").save("output.jpg")`. |
| `python-docx` | `from docx import Document`; `print([p.text for p in Document("input.docx").paragraphs])`. |
| `openpyxl` | `from openpyxl import load_workbook`; `book = load_workbook("input.xlsx", read_only=True); print(book.active["A1"].value); book.close()`. It does not calculate spreadsheet formulas. |
| `beautifulsoup4` | `from bs4 import BeautifulSoup`; `BeautifulSoup("<p>text</p>", "lxml").get_text()`. |
| `lxml` | `from lxml import etree`; parse untrusted XML with `etree.XMLParser(resolve_entities=False, no_network=True)`. |
| `pdfminer.six` | `from pdfminer.high_level import extract_text`; `print(extract_text("input.pdf"))`; also supports pdfplumber. |
| `pypdfium2` | `import pypdfium2 as pdfium`; `doc = pdfium.PdfDocument("input.pdf"); doc[0].render().to_pil().save("page.png"); doc.close()`. |
| `charset-normalizer` | `from charset_normalizer import from_bytes`; `print(from_bytes(b"text").best().encoding)` detects text encodings. |
| `cryptography` | `from cryptography.fernet import Fernet`; cryptographic dependency and API. Do not generate, rotate, or reveal user keys without authorization. |
| `cffi`, `pycparser` | `import cffi; ffi = cffi.FFI()`; `from pycparser import c_parser; c_parser.CParser().parse("int x;")`. Native-interface/C-parser support libraries, not PDF CLIs. |
| `et-xmlfile` | `from et_xmlfile import xmlfile`; streaming XML writer used by openpyxl, typically consumed through openpyxl. |
| `soupsieve` | `from bs4 import BeautifulSoup; import soupsieve; soupsieve.select("p", BeautifulSoup("<p>text</p>", "html.parser"))` selects HTML elements. |
| `typing-extensions` | `from typing_extensions import TypedDict`; backported typing support, not a CLI. |
| Venv bootstrap: `pip`, `setuptools` | `document-python -m pip list`; packaging support initialized by Debian's venv tooling. Do not alter the managed environment with it. |

The document venv also provides console programs. Initialize it with
`document-python -c 'pass'`, then invoke these by their full path without
changing system Python:

| Venv console program | Example invocation and role |
| --- | --- |
| `pymupdf` | `document-python -m pymupdf --help`; subcommands cover PDF inspection, text extraction, attachments, cleaning, and joining. |
| `pdfplumber` | `~/.local/share/document-tools/venv/bin/pdfplumber --help`; PDF layout/text extraction CLI. |
| `pdf2txt.py`, `dumppdf.py` | `~/.local/share/document-tools/venv/bin/pdf2txt.py --help`; `~/.local/share/document-tools/venv/bin/dumppdf.py --help`; pdfminer text/structure tools. |
| `pypdfium2` | `~/.local/share/document-tools/venv/bin/pypdfium2 --help`; PDFium rendering/inspection subcommands. |
| `normalizer` | `~/.local/share/document-tools/venv/bin/normalizer --help`; charset-normalizer text-encoding detection. |
| `cffi-gen-src` | `~/.local/share/document-tools/venv/bin/cffi-gen-src --help`; CFFI source generation for developers, not a document parser. |

`activate`, `activate.csh`, `activate.fish`, and `Activate.ps1` are shell
activation scripts, not standalone applications; Bash uses `source .../activate`.
Venv `pip`, `pip3`, and `pip3.11` belong to this environment. Prefer
`document-python -m pip` for read-only package inspection.

Read exact pins from `/opt/document-tools/requirements.txt`. Check integrity
with `document-python -m pip check`. Run the synthetic, local-only PDF/OCR,
graphics, document, and mail-client smoke checks with:

```bash
document-python /opt/document-tools/test-document-tools.py
```

## Browser automation and graphical support

Playwright 1.62.0 and Chromium are preinstalled. Browser binaries are in the
read-only `/ms-playwright`, selected by `PLAYWRIGHT_BROWSERS_PATH`. Do not
download another browser. Store profiles, downloads, and screenshots under home.

```bash
playwright --version
playwright screenshot --device="Desktop Chrome" https://example.com screenshot.png
```

For Node scripts, import the image's global module by its absolute path:

```javascript
const { chromium } = require("/usr/local/lib/node_modules/playwright");
(async () => {
  const browser = await chromium.launch({ headless: true, chromiumSandbox: false });
  try {
    const page = await browser.newPage();
    await page.setContent("<title>ready</title>");
    console.log(await page.title());
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
```

Run saved code with `node browser.js`. `chromiumSandbox: false` matches the
default container setup; do not add `SYS_ADMIN` or weaken isolation. If a task
requires Chromium sandboxing, request the appropriate deployment profile.

`Xvfb` is also installed: `Xvfb :99 -screen 0 1280x720x24 -nolisten tcp`
starts a foreground virtual display; graphical clients can use `DISPLAY=:99`
from another terminal. Stop only the display process you started.
**`xvfb-run` is present but currently fails because `xauth` is not installed.**
Use headless Playwright instead, or request the missing dependency.

## Networking, remote files, SSH, and mail

Connect only to authorized destinations; scan only authorized hosts. Raw-socket,
interface-management, packet-capture, or kernel-monitoring tools may fail for
the unprivileged user. Do not work around that by adding capabilities.

| Package | Purpose and invocation examples |
| --- | --- |
| `curl` | HTTP: `curl --fail --show-error --location -o download.bin https://example.com/file`; never include secrets in logged command lines. |
| `wget` | Download: `wget -O download.bin https://example.com/file`. |
| `dnsutils` / `bind9-dnsutils`, `bind9-host` | DNS: `dig example.com`, `host example.com`, `nslookup example.com`; `delv example.com` validates DNSSEC. `nsupdate` changes DNS and requires explicit authorization. |
| `iproute2` | Inspect interfaces/routes/listeners: `ip address show`, `ip route show`, `ss -ltnp`; do not change routes or interfaces. |
| `iputils-ping` | Reachability: `ping -c 3 HOST`; aliases `ping4` and `ping6`. |
| `netcat-openbsd` | `nc -vz HOST PORT`; `nc` selects `nc.openbsd`. Use an authorized host and specific port. |
| `nmap` | Unprivileged TCP connect scan: `nmap -sT -p 443 HOST`; `nping --help` describes the optional probe generator. |
| `mtr-tiny` | Route diagnostics: `mtr --report --report-cycles 3 HOST`; raw probes may be unavailable. |
| `traceroute` | `traceroute HOST`; protocol variants and Debian aliases are listed below. |
| `whois` | Registration lookup: `whois example.com`; no guarantee of complete results. |
| `openssh-client` | `ssh -p PORT USER@HOST`, `scp -P PORT file USER@HOST:path`, `sftp -P PORT USER@HOST`; inspect host fingerprints with `ssh-keygen -lf PUBLIC_KEY`. Do not disable host-key verification. |
| `openssh-server`, `openssh-sftp-server` | `sshd` and its SFTP subsystem provide operator-managed key-only access for `clawvm`. The sndbx hook manages server keys/configuration under `/run/sshd`; do not launch a second server or edit `/etc/ssh`. |
| `rsync` | Preview a copy: `rsync -an source/ destination/`; use `rsync -a` only when authorized. Avoid `--delete` unless specifically requested. |
| `rclone` | Configured remote storage: `rclone listremotes`; `rclone copy --dry-run source destination`. Do not expose remote credentials or upload private files without authorization. |
| `socat` | Socket/stream forwarding: `socat -V`; for an authorized connection, `socat - TCP:HOST:PORT`. Listeners and forwarding require explicit intent. |
| `msmtp` | SMTP submission: `msmtp --version`; after account setup and explicit send authorization, `msmtp --account=ACCOUNT RECIPIENT < message.eml`. |
| `isync` | IMAP synchronization: `mbsync --version`; after account setup and authorization, `mbsync CHANNEL`. Synchronization can modify local and remote mailbox state according to configuration. |

Email accounts are not supplied by the image. Store private `~/.msmtprc`,
`~/.mbsyncrc`, and any token-helper configuration securely under home.
Use TLS and the provider's supported authentication; OAuth2 may need a separate
helper. Never print credentials, disable certificate verification, or send
test mail without permission. `mbsync-get-cert` and `mdconvert` are ancillary
certificate/Maildir tools, not substitutes for account authorization.

## Database clients

These are clients, not preconfigured database servers. Ask for the intended
connection/account; no PostgreSQL, MySQL/MariaDB, or Redis server is implied.
Never put passwords in arguments or publish database contents.

| Package | Purpose and invocation examples |
| --- | --- |
| `postgresql-client` (PostgreSQL 15) | `psql --version`; `psql -h HOST -U USER -d DATABASE -c 'SELECT 1'`; `pg_isready -h HOST`; use `pg_dump --help`/`pg_restore --help` before authorized backup/restore. |
| `default-mysql-client` (MariaDB clients) | `mysql --version` or `mariadb --version`; `mysql -h HOST -u USER -p -e 'SELECT 1'` prompts for a password. `mysqldump`/`mariadb-dump` provide logical backups. |
| `sqlite3` | Local database inspection: `sqlite3 -readonly database.sqlite '.tables'`; for an expendable example, `sqlite3 :memory: 'SELECT 1;'`. |
| `redis-tools` | `redis-cli --version`; `redis-cli -h HOST -p PORT PING`. `redis-check-rdb`, `redis-check-aof`, and `redis-benchmark` exist; do not repair data or generate benchmark traffic without authorization. |

Do not modify OpenClaw's private databases as a generic repair step.
PostgreSQL maintenance programs such as `dropdb`, `dropuser`, `reindexdb`,
and `vacuumdb` and MariaDB repair/import tools require explicit task approval.
The distro installs dispatch wrappers named `createlang`, `droplang`,
`pg_receivexlog`, `pgbench`, and `vacuumlo` without corresponding PostgreSQL 15
backing programs here. Do not treat these wrappers as available functionality.

## Processes, terminals, performance, and permissions

| Package | Purpose and invocation examples |
| --- | --- |
| `procps` | `ps -eo pid,comm,etime`, `pgrep -a PROGRAM`, `free -h`, `vmstat 1 3`, `uptime`; `top` is interactive. |
| `psmisc` | `pstree -p`, `fuser FILE`, `prtstat PID`, `pslog PID`; `peekfd` may require privileges. `killall` is installed but must not be used for broad name-based termination. |
| `htop`, `btop` | Interactive process/resource monitors: `htop`, `btop`; prefer `ps`/`free` for scripted output. |
| `iftop` | Interactive interface traffic: `iftop -h`; packet capture normally needs privileges unavailable to this user. |
| `iotop` | I/O monitor: `iotop --help`; Debian's implementation is `iotop-py`. Kernel task accounting/privileges may prevent runtime monitoring. |
| `sysstat` | Dependency-provided resource tools: `iostat -xz 1 2`, `mpstat 1 2`, `pidstat 1 2`, `sar -u 1 2`; metrics may be limited inside containers. |
| `lsof` | Open files: `lsof -p PID`; visibility is limited by process permissions. |
| `strace` | Trace a process you launch: `strace -o trace.log COMMAND`; attach with `strace -p PID` only when permitted. Seccomp/ptrace restrictions may prevent tracing. |
| `tmux` | Persistent terminal session: `tmux new -s work`; list with `tmux ls`; attach with `tmux attach -t work`. |
| `screen` | Alternative terminal multiplexer: `screen -S work`, `screen -ls`, `screen -r work`. |
| `parallel` | Bounded parallel jobs: `printf '%s\n' a b \| parallel --jobs 2 printf '%s\\n' {}`. Check job exit status; do not run arbitrary untrusted input as shell code. |
| `entr` | Watch selected files: `printf '%s\n' script.py \| entr python3 script.py`; this stays running until stopped. |
| `pv` | Stream progress: `pv input.bin > output.bin`; use separate source/output paths. |
| `util-linux` | Mount/storage inspection: `findmnt -T "$HOME"`, `lsblk`; CPU info: `lscpu`; serialized commands: `flock LOCKFILE COMMAND`; session recording: `script -q -c COMMAND transcript.txt` can capture secrets, so use carefully. |
| `acl` | Inspect `getfacl FILE`; `setfacl` and `chacl` modify permissions and must not be used to bypass host policy. |
| `attr` | Inspect `getfattr -d FILE` or `attr -l FILE`; `setfattr` changes extended attributes only where authorized and supported. |
| `libcap2-bin` | Inspect `getcap FILE`, `getpcaps PID`, or `capsh --print`; do not use `setcap` or capability escalation to bypass isolation. |

Stop only processes belonging to your task, using a specific verified PID
(`kill PID`). Do not use `pkill` or `killall` for name-based termination.
The availability of a utility does not override task boundaries.

## Archives, compression, and cryptography

| Package | Purpose and invocation examples |
| --- | --- |
| `tar` | List first: `tar -tf archive.tar`; create: `tar -czf archive.tar.gz directory`; extract untrusted archives only into a fresh task directory after checking paths. |
| `zip`, `unzip` | `zip -r archive.zip directory`; `unzip -l archive.zip`; `unzip archive.zip -d destination`. |
| `p7zip-full` / `p7zip` | `7z l archive.7z`; `7z x archive.7z -odestination`. `7za`/`7zr` have narrower format support. |
| `gzip` | Keep originals: `gzip -c input.txt > input.txt.gz`; `gzip -dc input.txt.gz > output.txt`; `gunzip`/`zcat` are companion commands. |
| `bzip2` | `bzip2 -c input.txt > input.txt.bz2`; `bzip2 -dc input.txt.bz2 > output.txt`; `bunzip2`/`bzcat` are companions. |
| `xz-utils` | `xz -c input.txt > input.txt.xz`; `xz -dc input.txt.xz > output.txt`; `unxz`/`xzcat` and legacy LZMA tools are included. |
| `zstd` | `zstd -c input.txt > input.txt.zst`; `zstd -dc input.txt.zst > output.txt`; `pzstd` supports parallel processing. |
| `age` | Inspect syntax with `age --help`; authorized encryption: `age -r RECIPIENT -o encrypted.age input.txt`; `age-keygen` manages identities, which must remain private. |
| `openssl` | Hashing: `openssl dgst -sha256 FILE`; inspect a public certificate: `openssl x509 -in certificate.pem -noout -dates`. |
| `gnupg` | Detached signature verification: `gpg --verify file.sig file`; `gpgv` verifies using a specified trusted keyring. Do not import/trust arbitrary keys or expose private key material. |

## Locale, fonts, completion, and supporting packages

These are installed resources or runtime dependencies, not missing standalone
applications that agents should reinstall.

| Packages/data | Access and usage |
| --- | --- |
| `ca-certificates` | System trust bundle `/etc/ssl/certs/ca-certificates.crt`, consumed by TLS clients. Do not modify system trust or disable certificate verification. |
| `debian-archive-keyring`, `debian-keyring` | Package/archive/developer verification keys under `/usr/share/keyrings`; list with `dpkg-query -L PACKAGE`. APT is for image builds, not runtime changes. |
| `locales`, `libc-l10n`, `tzdata` | English UTF-8 is generated; inspect `locale` and `locale -a`. Time-zone data is under `/usr/share/zoneinfo`; `TZ=UTC date` selects a zone for one command. Do not run `locale-gen`/`update-locale` against the read-only system. |
| `lsb-release` | Distribution summary: `lsb_release -a`. |
| `fonts-noto-core` | General and multilingual text fonts including Cyrillic/Thai; discover with `fc-list` and `fc-match 'Noto Sans Thai'`. |
| Browser/document font dependencies | `fonts-noto-color-emoji`, `fonts-freefont-ttf`, `fonts-ipafont-gothic`, `fonts-liberation`, `fonts-tlwg-loma-otf`, `fonts-unifont`, `fonts-urw-base35`, `fonts-wqy-zenhei`, `xfonts-scalable`, and `xfonts-encodings`. Fontconfig's `fc-list`/`fc-match` help select fonts; not every font supports every script. |
| `x11-xkb-utils`, `xkb-data`, `xserver-common`, `xfonts-utils` | Virtual-display keyboard/font support; X utilities need a running display and correct `DISPLAY`. Do not rewrite system X/font configuration. |
| `pandoc-data`, `poppler-data`, `nmap-common` | Templates, character maps, and network probe data used automatically by their main tools. |
| Debian Python tool dependencies | `python3-argcomplete`, `python3-click`, `python3-colorama`, `python3-packaging`, `python3-pathspec`, `python3-pkg-resources`, `python3-setuptools`, `python3-userpath`, `python3-wheel`, `python3-yaml`, and pip/setuptools wheel packages support pipx, pip, venv and yamllint. Prefer the main tool; these are not the document venv. |
| Native/runtime support libraries | Browser X11/GTK/audio/NSS, PDF/font/image libraries, database client libraries, and compiler/Python headers are installed as needed by the named tools. They are not separately callable document applications. |

## Additional installed entrypoints

The package frontends above are the recommended starting point. The following
secondary executables are also installed beyond the Node base. Lists include
specialized converters, compatibility aliases, training tools, and privileged
maintenance helpers, not a recommendation to run them. Invoke the named tool
directly with its documented arguments; use its `--help` where supported.
For legacy converters, follow the corresponding primary-tool examples and
inspect usage before supplying files. Do not execute a maintenance command
merely to discover what it does.

| Family | Additional entrypoints and intended use |
| --- | --- |
| Bash/Python completion | `dh_bash-completion` is Debian packaging support. `activate-global-python-argcomplete`, `python-argcomplete-check-easy-install-script`, `python-argcomplete-tcsh`, `register-python-argcomplete` configure completion; use the existing Bash setup rather than editing system files. |
| Python build flags | `python3.11-config`, `x86_64-linux-gnu-python3-config`, `x86_64-linux-gnu-python3.11-config`; for example `python3.11-config --includes`. |
| DNS | `mdig` performs batch lookups; `dnstap-read` reads DNS capture files. For ordinary queries use `dig`; `nsupdate` performs authorized DNS updates. |
| Ghostscript | `ghostscript` aliases `gs`; `dvipdf`, `eps2eps`, `pdf2dsc`, `ps2epsi`, `ps2pdf12`, `ps2pdf13`, `ps2pdf14`, `ps2pdfwr`, `ps2ps`, `ps2ps2`, `ps2txt` convert document formats. `gsbj`, `gsdj`, `gsdj500`, `gslj`, `gslp`, `gsnd` are printer/renderer frontends. `pf2afm`, `pfbtopfa`, `pphs`, `printafm`, `update-gsfontmap` are font/legacy helpers. Prefer `gs`/`ps2pdf` for new workflows. |
| IP/traffic/kernel networking | `arpd`, `bridge`, `ctstat`, `dcb`, `devlink`, `genl`, `lnstat`, `nstat`, `rdma`, `routel`, `rtacct`, `rtmon`, `rtstat`, `tc`, `tipc`, `vdpa`; for example `bridge link show` and `nstat -a`. Many need privileges for changes. |
| Tracing/probing aliases | `mtr-packet` is mtr's helper; `lft.db`, `tcptraceroute.db`, `traceproto.db`, `traceroute-nanog`, `traceroute.db`, `traceroute6.db` implement route-probe variants. Use the `traceroute` frontend for normal work. |
| Pager/editor helpers | `lessecho`, `lessfile`, `lesskey`, `lesspipe`, `helpztags`; pager preprocessing/key maps and Vim documentation tags, not alternative editors. |
| GNU Parallel | `env_parallel`, `env_parallel.bash`, `env_parallel.csh`, `env_parallel.dash`, `env_parallel.fish`, `env_parallel.ksh`, `env_parallel.mksh`, `env_parallel.sh`, `env_parallel.tcsh`, `env_parallel.zsh` preserve shell context (the corresponding shell may not be installed). `niceload`, `parcat`, `parset`, `parsort`, `sem`, `sql` provide throttling, stream/job helpers, semaphores and SQL clients. Prefer `parallel --jobs N COMMAND`. |
| Process/performance | `pstree.x11` is a pstree variant; `strace-log-merge` merges per-process traces. `cifsiostat`, `sadf`, `sar.sysstat`, `tapestat` cover filesystem/device statistics and sysstat data; e.g. `cifsiostat 1 2`. |
| Socket/transfer helpers | `filan` inspects file descriptors; `procan` reports process context; `rrsync` restricts an rsync server command; `rsync-ssl` wraps TLS transport. Use `rsync`/`socat` for normal client work. |
| PostgreSQL 15 | `clusterdb`, `createdb`, `createuser`, `dropdb`, `dropuser`, `pg_amcheck`, `pg_basebackup`, `pg_config`, `pg_dump`, `pg_dumpall`, `pg_isready`, `pg_receivewal`, `pg_recvlogical`, `pg_restore`, `pg_verifybackup`, `psql`, `reindexdb`, `vacuumdb`. Examples: `pg_config --version`, `pg_dump --help`; maintenance, replication, backup, and restore need authorization. Some version-specific binaries live in `/usr/lib/postgresql/15/bin`. |
| MariaDB/MySQL | `mariadb-access`, `mariadb-admin`, `mariadb-analyze`, `mariadb-binlog`, `mariadb-check`, `mariadb-conv`, `mariadb-convert-table-format`, `mariadb-dump`, `mariadb-dumpslow`, `mariadb-find-rows`, `mariadb-fix-extensions`, `mariadb-hotcopy`, `mariadb-import`, `mariadb-optimize`, `mariadb-plugin`, `mariadb-repair`, `mariadb-report`, `mariadb-secure-installation`, `mariadb-setpermission`, `mariadb-show`, `mariadb-slap`, `mariadb-tzinfo-to-sql`, `mariadb-waitpid`, `mariadbcheck`. `innotop`/`mytop` are interactive DB monitors. Example: `mariadb-dump --help`; never invoke repair/security setup against an unspecified server. |
| MySQL compatibility/helpers | `mysql_find_rows`, `mysql_fix_extensions`, `mysql_waitpid`, `mysqlaccess`, `mysqladmin`, `mysqlanalyze`, `mysqlcheck`, `mysqldump`, `mysqldumpslow`, `mysqlimport`, `mysqloptimize`, `mysqlrepair`, `mysqlreport`, `mysqlshow`, `mysqlslap`, `msql2mysql`, `my_print_defaults`, `perror`, `replace`, `resolve_stack_dump`. Example: `perror 2` explains an error code. `my_print_defaults` may reveal configured secrets; do not log its output. |
| Tesseract training | `ambiguous_words`, `classifier_tester`, `cntraining`, `combine_lang_model`, `combine_tessdata`, `dawg2wordlist`, `lstmeval`, `lstmtraining`, `merge_unicharsets`, `mftraining`, `set_unicharset_properties`, `shapeclustering`, `text2image`, `unicharset_extractor`, `wordlist2dawg`. Example: `text2image --help`; use `tesseract` with the preinstalled languages for normal OCR. |
| X keyboard support | `setxkbmap`, `xkbbell`, `xkbcomp`, `xkbevd`, `xkbprint`, `xkbvleds`, `xkbwatch`; e.g. `setxkbmap -query` against an authorized running X display. |
| X font support | `bdftopcf`, `bdftruncate`, `fonttosfnt`, `mkfontdir`, `mkfontscale`, `ucs2any`, `update-fonts-alias`, `update-fonts-dir`, `update-fonts-scale`; specialized font conversion/index maintenance, not needed for ordinary PDF rendering. |
| Compression/password helpers | `zipcloak`, `zipnote`, `zipsplit`; `unzstd`, `zstdcat`, `zstdgrep`, `zstdless`, `zstdmt`. Example: `zstdcat input.zst`. `mkpasswd` from `whois` hashes passwords; do not pass or reveal real credentials in arguments/logs. |
| Locale helpers | `locale-gen`, `update-locale`, `validlocale`; inspect with `validlocale en_US.UTF-8`, but do not modify the read-only locale installation. |

## OpenClaw, Caddy, and image launchers

OpenClaw itself is **not baked into the read-only image**. A deployment may
install and update it below home. The image's `/usr/local/bin/openclaw` resolves
the installer-managed `~/.openclaw/tools/node-*/bin/openclaw` executable.
Use `openclaw --help`, `openclaw gateway status --deep`, and
`openclaw gateway health` for diagnostics without disclosing credentials.
Installation is an operator action using OpenClaw's official installer, not
an automatic response to a missing command.

`/usr/local/bin/clawvm-entrypoint` loads private runtime environment values,
initializes the document venv, then runs executable `~/config/start.sh` or
sleeps indefinitely if it is absent. Do not launch a second entrypoint inside
an already running VM. `/usr/local/bin/init-document-tools` performs the
idempotent offline venv initialization; ordinary callers should use
`document-python`. `/opt/sndbx-image/app.py` is an sndbx lifecycle hook invoked
with operator-supplied context, not an agent task runner.

The supplied startup script supervises the Gateway and starts `caddy` using
`~/config/Caddyfile`. Templates live under `~/config` when supplied with the
deployment. Caddy is installed in the image; inspect with `caddy version` or
validate a known configuration with
`caddy validate --config "$HOME/config/Caddyfile" --adapter caddyfile`.
Starting/reloading services requires operator authorization.

The Gateway is normally loopback-only on
`127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}`. Caddy provides the external
HTTP/HTTPS/WebSocket endpoint and internal-CA TLS; do not expose the Gateway
directly, add Gateway TLS, or change forwarded-header/trusted-proxy behavior.
Published ports and allowed addresses belong to deployment configuration,
not this shared reference. Inspect listeners with `ss -ltnp`.

SSH, when enabled by sndbx, is key-only for `clawvm`. Runtime SSH keys below
`/run` are regenerated; persistent authorized keys are private home data.
The image does not provide a general service manager or root administration
access to agents.

After container recreation, OpenClaw may temporarily refuse startup because
the previous container's owner lease is still active. The observed lease lasts
up to five minutes; allow the supervisor to recover and check Gateway health.
Do not delete lock files or change its databases simply to bypass the wait.

## Updating the persistent OpenClaw installation

This deployment differs from an image that bundles OpenClaw in `/usr/local`:
the **package lives in persistent home storage**, while the read-only image
provides Node/npm and `/usr/local/bin/openclaw`, a launcher. Rebuilding the image
does not update the home-installed OpenClaw package.

There can be two Node runtimes: the image's `/usr/local/bin/node` and the
installer's `~/.openclaw/tools/node-vVERSION/bin/node`. npm's default global
prefix follows the selected runtime. An update launched under the image runtime
can select `/usr/local` even when its OpenClaw package is under home. The updater
then reports `global-install-foreign-destination` because the image-owned
launcher is not owned by that package. This message does not prove that another
OpenClaw package actually exists under `/usr/local/lib/node_modules`.
Do not remove the image launcher, make the root filesystem writable, or use
`sudo npm install -g` to bypass the ownership check.

Use the terminal maintenance procedure below. The web UI updater inherits the
Gateway process's environment, not exports made in a separate terminal.
Do not assume a terminal fix changes the web UI's update destination.

### 1. Prepare and inspect the existing installation

Obtain authorization for the update and arrange a consistent backup through
the deployment operator first, including persistent OpenClaw state and local
configuration. Keep the same user, HOME, profile, OPENCLAW_STATE_DIR and
OPENCLAW_CONFIG_PATH throughout. Do not print their private contents.

Inspect the installer-managed runtime link and npm executable:

```bash
runtime="$(readlink -f "$HOME/.openclaw/tools/node/bin/node")"
prefix="$(dirname "$(dirname "$runtime")")"
printf 'Runtime: %s\nPrefix: %s\n' "$runtime" "$prefix"
stat -Lc '%A %U:%G %n' "$prefix/bin/npm" "$prefix/bin/npx"
```

This discovery applies to the official local-prefix installer layout used
here. If the runtime link is absent or the prefix does not identify the
existing `~/.openclaw/tools/node-vVERSION` installation, stop and inspect the
actual launcher with the operator. Do not guess the newest versioned directory
or create a second installation.

If npm's ownership check fails with `EACCES`, inspect its script ACL:

```bash
getfacl "$prefix/lib/node_modules/npm/bin/npm-cli.js"
test -x "$prefix/bin/npm"
```

A file owned by `clawvm` with `user::rw-` cannot be executed by that owner,
even if a named `user:clawvm:rwx` ACL entry or the group grants execute.
For this specific defect, the owning user can restore only the missing owner
execute bits, after verifying the targets belong to this installation:

```bash
chmod u+x -- "$prefix/lib/node_modules/npm/bin/npm-cli.js" \
  "$prefix/lib/node_modules/npm/bin/npx-cli.js"
"$prefix/bin/npm" --version
```

This is a targeted repair, not a routine permission reset. Do not recursively
chmod/chown the home directory, change host ACL policy, or use `chmod 777`.
If ownership/access prevents the targeted repair, ask the host operator.

### 2. Preview with an explicit persistent npm destination

The following subshell uses the image Node explicitly, keeps the existing
package as the update target, and pins both npm prefix environment spellings
so a runtime handoff cannot redirect installation into `/usr/local`.
It does not modify `.env`, npm configuration files, or the parent shell.

```bash
(
  set -eu
  runtime="$(readlink -f "$HOME/.openclaw/tools/node/bin/node")"
  prefix="$(dirname "$(dirname "$runtime")")"
  case "$prefix" in
    "$HOME"/.openclaw/tools/node-v*) ;;
    *) printf 'Unexpected OpenClaw installation prefix: %s\n' "$prefix" >&2; exit 1 ;;
  esac
  cli="$prefix/lib/node_modules/openclaw/openclaw.mjs"
  if [ ! -x "$runtime" ] || [ ! -x "$prefix/bin/npm" ] || [ ! -f "$cli" ]; then
    printf 'The selected OpenClaw installation is incomplete or not executable.\n' >&2
    exit 1
  fi
  export NPM_CONFIG_PREFIX="$prefix" npm_config_prefix="$prefix"
  if [ "$(npm prefix -g)" != "$prefix" ]; then
    printf 'npm did not select the persistent OpenClaw prefix.\n' >&2
    exit 1
  fi
  /usr/local/bin/node "$cli" update --dry-run --no-restart --json
)
```

Check the reported installation root, current/target versions, actions, notes,
and any preflight refusals. A dry run does not install packages, migrate them,
or restart the Gateway; it is not proof that every later installation step
will succeed. The updater may still record its diagnostic run.

### 3. Update, then activate through the deployment owner

Once the backup and plan are approved, repeat the same subshell with
`--dry-run` removed from its final command. Keep `--no-restart`.
Do not add `--yes` or `--accept-capabilities` without reviewing the downgrade
or plugin-capability changes they approve.

This VM's Gateway is supervised by `~/config/start.sh`, not a supported
OpenClaw-managed system service. A successful package update with
`--no-restart` does not mean the old Gateway process has loaded the new code.
Ask the operator to restart the existing VM via sndbx or its existing Compose
deployment. Do not install a second service with `openclaw gateway install`,
run another Gateway, or use `gateway restart` as a substitute for the actual
deployment owner.

After the restart, check:

```bash
openclaw --version
openclaw gateway status --deep
openclaw gateway health
```

Also verify the operator-facing HTTP/HTTPS endpoint and the required channels.
Allow for the owner-lease delay described above. If preflight, migration,
plugin synchronization, or health checks fail, keep backups and report the
exact failed step. Do not blindly retry a raw npm install, delete lock/state
files, run `doctor --fix`, or roll back code over a migrated database.
Follow the version-specific recovery procedure instead.

Official references:
[OpenClaw updating](https://docs.openclaw.ai/install/updating) and
[Node/runtime selection](https://docs.openclaw.ai/install/node).

## Privacy and task boundaries

Never print, copy, commit, or disclose `~/.env`, OpenClaw credentials/state,
SSH secrets, Caddy CA private keys, browser profiles, mail tokens, or database
credentials. Avoid dumping process arguments or configurations that may contain
secrets. Do not upload private workspace files to an untrusted destination.

Inspect targets before destructive operations, preserve input data, and report
failures explicitly. Do not override read-only mounts, ACLs, capability limits,
network policy, or the machine-specific restrictions in [AGENTS.md](AGENTS.md).
Report commands run, files changed, validation performed, and remaining blockers.
