FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SBBSCTRL=/sbbs/ctrl
ENV SBBSEXEC=/sbbs/exec
ENV SBBSDIR=/sbbs
ENV TERM=ansi-bbs
ENV LANG=en_US.UTF-8
ENV LD_LIBRARY_PATH="/sbbs/exec:${LD_LIBRARY_PATH}"

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    pkg-config \
    patch \
    perl \
    python3 \
    wget \
    curl \
    gnupg \
    software-properties-common \
    libncurses-dev \
    libncursesw5-dev \
    libnspr4-dev \
    libcap-dev \
    libarchive-dev \
    zip \
    unzip \
    ncurses-term \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Generate locale (fixes perl warnings)
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Add DOSEMU2 PPA and install (for DOS doors)
RUN curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xebe1b5ded2ad45d6' | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/ubuntu-dosemu2-ppa.gpg && \
    echo "deb https://ppa.launchpadcontent.net/dosemu2/ppa/ubuntu noble main" > /etc/apt/sources.list.d/dosemu2.list && \
    apt-get update && apt-get install -y dosemu2 && rm -rf /var/lib/apt/lists/*

# Download Nelgin's DOSEMU2 config (optional, for DOS doors)
RUN mkdir -p /tmp/dosemu2-config && \
    cd /tmp/dosemu2-config && \
    wget -q https://www.endofthelinebbs.com/dosemu2.tar.gz && \
    tar xzf dosemu2.tar.gz && rm dosemu2.tar.gz || true

# Create directory structure (MUST include /sbbs/exec before make install)
RUN mkdir -p /sbbs/repo /sbbs/ctrl /sbbs/data /sbbs/mods /sbbs/temp \
    /sbbs/node1 /sbbs/node2 /sbbs/node3 /sbbs/node4 /sbbs/exec

# Clone Synchronet
WORKDIR /sbbs
RUN git clone https://gitlab.synchro.net/main/sbbs.git /sbbs/repo

# Build Synchronet
WORKDIR /sbbs/repo/src/sbbs3
RUN make RELEASE=1 SBBSDIR=/sbbs NOCAP=1 2>&1
RUN make RELEASE=1 SBBSDIR=/sbbs NOCAP=1 install 2>&1

# Set up directory structure with symlinks to repo
WORKDIR /sbbs
RUN ln -sf /sbbs/repo/docs /sbbs/docs && \
    ln -sf /sbbs/repo/text /sbbs/text && \
    ln -sf /sbbs/repo/web /sbbs/web && \
    ln -sf /sbbs/repo/webv4 /sbbs/webv4 && \
    ln -sf /sbbs/repo/xtrn /sbbs/xtrn

# Copy ctrl (writable config)
RUN cp -r /sbbs/repo/ctrl/* /sbbs/ctrl/
RUN cp -r /sbbs/repo/node1/* /sbbs/node1/ 2>/dev/null || true

# Ensure JavaScript files in exec
RUN if [ -d /sbbs/exec ] && [ ! -L /sbbs/exec ]; then \
        cp -rn /sbbs/repo/exec/* /sbbs/exec/ 2>/dev/null || true; \
    fi

# Copy shared libraries
RUN find /sbbs/repo/src -name "*.so*" -path "*/gcc.linux.*.release/*" \
    -exec cp {} /sbbs/exec/ \; 2>/dev/null || true

# Enable DOSEMU
RUN if [ -f /sbbs/ctrl/sbbs.ini ]; then \
        sed -i 's/^;*UseDOSemu=.*/UseDOSemu=true/' /sbbs/ctrl/sbbs.ini 2>/dev/null || true; \
    fi

# Compile terminfo
RUN if [ -f /sbbs/repo/install/terminfo/ansi-bbs.src ]; then \
        tic /sbbs/repo/install/terminfo/ansi-bbs.src 2>/dev/null || true; \
    fi

RUN chmod -R 755 /sbbs/exec 2>/dev/null || true

# Verify installation
RUN echo "=== Verifying Synchronet installation ===" && \
    ls -la /sbbs/exec/sbbs && \
    echo "=== DOSEMU2 version ===" && \
    (dosemu --version 2>/dev/null || echo "DOSEMU2 not available")

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 23 22 80 443 513 21 25 110 119

WORKDIR /sbbs
ENTRYPOINT ["/entrypoint.sh"]
CMD []