FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV SBBSCTRL=/sbbs/ctrl
ENV SBBSEXEC=/sbbs/exec
ENV TERM=xterm

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    libncurses-dev \
    libnspr4-dev \
    libcap-dev \
    libarchive-dev \
    pkg-config \
    zip \
    unzip \
    perl \
    python3 \
    libmozjs-78-dev \
    && rm -rf /var/lib/apt/lists/*

# Check where archive.h is
RUN find /usr -name "archive.h" 2>/dev/null || echo "archive.h not found"
RUN dpkg -L libarchive-dev | grep -i archive


# Clone Synchronet
RUN git clone --depth 1 https://gitlab.synchro.net/main/sbbs.git /sbbs

# Build
WORKDIR /sbbs/src/sbbs3
ENV SBBSDIR=/sbbs
RUN make RELEASE=1 SBBSDIR=/sbbs 2>&1 && \
    ls -la /sbbs/exec/


# Install all binaries to exec directory
RUN find /sbbs/src -path "*/gcc.linux.aarch64.exe.release/*" -type f -executable -exec cp {} /sbbs/exec/ \;
RUN ls -la /sbbs/exec/sbbs /sbbs/exec/scfg

# Copy default config files
RUN cp -r /sbbs/ctrl.new/* /sbbs/ctrl/ 2>/dev/null || true
RUN cp -r /sbbs/text.new/* /sbbs/text/ 2>/dev/null || true

RUN ls -la /sbbs/exec/sbbs

# Create required directories
RUN mkdir -p /sbbs/data /sbbs/ctrl /sbbs/text /sbbs/node1 /sbbs/node2 /sbbs/node3 /sbbs/node4


EXPOSE 513 23

WORKDIR /sbbs
CMD ["/sbbs/exec/sbbs"]