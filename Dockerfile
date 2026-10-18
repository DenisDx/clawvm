# syntax=docker/dockerfile:1.7
ARG NODE_IMAGE=node:24-bookworm
FROM ${NODE_IMAGE}

ARG YQ_VERSION=v4.45.4
ARG YQ_SHA256=4216b9d9fddd9c0c569b74161870f136800ac233e6c15a2e2b468e93fab54365
ARG PLAYWRIGHT_VERSION=1.62.0

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/clawvm \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    PATH=/home/clawvm/.local/bin:/home/clawvm/.openclaw/bin:${PATH} \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        acl \
        age \
        attr \
        bash-completion \
        btop \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        debian-archive-keyring \
        debian-keyring \
        default-mysql-client \
        dnsutils \
        entr \
        fd-find \
        file \
        fonts-noto-core \
        fzf \
        g++ \
        gcc \
        git \
        ghostscript \
        gnupg \
        gzip \
        htop \
        iftop \
        iotop \
        iproute2 \
        iputils-ping \
        isync \
        jq \
        less \
        librsvg2-bin \
        locales \
        lsb-release \
        lsof \
        make \
        mtr-tiny \
        msmtp \
        nano \
        netcat-openbsd \
        nmap \
        openssh-client \
        openssh-server \
        openssl \
        p7zip-full \
        pandoc \
        parallel \
        pkg-config \
        poppler-utils \
        postgresql-client \
        procps \
        psmisc \
        pv \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        pipx \
        qpdf \
        redis-tools \
        ripgrep \
        rclone \
        rsync \
        shellcheck \
        socat \
        sqlite3 \
        libsqlite3-dev \
        screen \
        strace \
        tar \
        tesseract-ocr \
        tesseract-ocr-eng \
        tesseract-ocr-rus \
        tesseract-ocr-tha \
        tmux \
        traceroute \
        tree \
        tzdata \
        unzip \
        util-linux \
        vim-common \
        vim-tiny \
        wget \
        whois \
        xxd \
        xz-utils \
        yamllint \
        zip \
        zstd \
    && curl --fail --location --silent --show-error \
        --output /tmp/caddy-stable.gpg \
        https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    && gpg --dearmor --output /usr/share/keyrings/caddy-stable-archive-keyring.gpg /tmp/caddy-stable.gpg \
    && curl --fail --location --silent --show-error \
        --output /etc/apt/sources.list.d/caddy-stable.list \
        https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    && apt-get update \
    && apt-get install -y --no-install-recommends caddy \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && corepack enable \
    && architecture="$(dpkg --print-architecture)" \
    && test "${architecture}" = "amd64" \
    && archive="yq_linux_${architecture}.tar.gz" \
    && curl --fail --location --silent --show-error \
        --output "/tmp/${archive}" \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${archive}" \
    && printf '%s  %s\n' "${YQ_SHA256}" "/tmp/${archive}" | sha256sum --check --status \
    && tar --extract --gzip --file "/tmp/${archive}" --directory /tmp "./yq_linux_${architecture}" \
    && install --mode=0755 "/tmp/yq_linux_${architecture}" /usr/local/bin/yq \
    && ln --symbolic /usr/bin/fdfind /usr/local/bin/fd \
    && npm install --global "playwright@${PLAYWRIGHT_VERSION}" \
    && PLAYWRIGHT_BROWSERS_PATH=/ms-playwright playwright install --with-deps chromium \
    && printf '%s\n' \
        'PermitRootLogin no' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'UsePAM no' \
        'AllowUsers clawvm' \
        > /etc/ssh/sshd_config.d/clawvm.conf \
    && rm -rf /var/lib/apt/lists/* /tmp/caddy-stable.gpg "/tmp/yq_linux_${architecture}" "/tmp/${archive}"

COPY docker/document-requirements.txt /opt/document-tools/requirements.txt
RUN python3 -m pip --isolated download --no-cache-dir --only-binary=:all: \
        --dest /opt/document-tools/wheels -r /opt/document-tools/requirements.txt \
    && cd /opt/document-tools \
    && sha256sum requirements.txt wheels/*.whl > SHA256SUMS

COPY docker/init-document-tools.sh /usr/local/bin/init-document-tools
COPY docker/document-python /usr/local/bin/document-python
COPY docker/test-document-tools.py /opt/document-tools/test-document-tools.py
RUN chmod 0755 /usr/local/bin/init-document-tools /usr/local/bin/document-python \
    && chmod -R a+rX /opt/document-tools

ENV XDG_CACHE_HOME=/home/clawvm/.cache

ENV XDG_CONFIG_HOME=/home/clawvm/.config \
    XDG_DATA_HOME=/home/clawvm/.local/share

RUN groupmod --new-name clawvm node \
    && usermod --login clawvm --home /home/clawvm --shell /bin/bash node \
    && usermod --password "$(openssl passwd -6 "$(openssl rand -hex 32)")" clawvm \
    && mkdir --parents /home/clawvm/.cache /home/clawvm/config /home/clawvm/.openclaw/workspace \
    && chown --recursive clawvm:clawvm /home/clawvm

COPY docker/entrypoint.sh /usr/local/bin/clawvm-entrypoint
COPY docker/load-clawvm-env.sh /usr/local/lib/clawvm/load-env.sh
COPY docker/openclaw /usr/local/bin/openclaw
RUN chmod 0755 /usr/local/bin/clawvm-entrypoint /usr/local/bin/openclaw \
    && printf '%s\n' \
        'if [[ -r /usr/local/lib/clawvm/load-env.sh ]]; then' \
        '    source /usr/local/lib/clawvm/load-env.sh' \
        'fi' \
        >> /etc/bash.bashrc \
    && printf '%s\n' \
        'source /usr/local/lib/clawvm/load-env.sh' \
        > /etc/profile.d/clawvm-env.sh \
    && chmod 0644 /usr/local/lib/clawvm/load-env.sh /etc/profile.d/clawvm-env.sh

COPY app.py /opt/sndbx-image/app.py
RUN chmod 0755 /opt/sndbx-image/app.py

USER clawvm
WORKDIR /home/clawvm

ENTRYPOINT ["/usr/local/bin/clawvm-entrypoint"]