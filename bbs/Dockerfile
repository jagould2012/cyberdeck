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
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Clone Synchronet
RUN git clone --depth 1 https://gitlab.synchro.net/main/sbbs.git /sbbs

# Build main Synchronet (RELEASE build)
WORKDIR /sbbs/src/sbbs3
ENV SBBSDIR=/sbbs
RUN make RELEASE=1 SBBSDIR=/sbbs 2>&1 && \
    echo "=== Main build completed ==="

# Copy executables from the MAIN build directory
# Handles both x64 and aarch64 architectures
RUN ARCH=$(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/aarch64/') && \
    MAIN_EXE_DIR="/sbbs/src/sbbs3/gcc.linux.${ARCH}.exe.release" && \
    MAIN_LIB_DIR="/sbbs/src/sbbs3/gcc.linux.${ARCH}.lib.release" && \
    if [ -d "$MAIN_EXE_DIR" ]; then \
        cp "$MAIN_EXE_DIR"/* /sbbs/exec/; \
    fi && \
    if [ -d "$MAIN_LIB_DIR" ]; then \
        cp "$MAIN_LIB_DIR"/*.so /sbbs/exec/; \
    fi

# Copy executables from subdirectory builds (scfg, uedit, umonitor, etc.)
RUN ARCH=$(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/aarch64/') && \
    for subdir in scfg uedit umonitor; do \
        EXE_DIR="/sbbs/src/sbbs3/${subdir}/gcc.linux.${ARCH}.exe.release"; \
        if [ -d "$EXE_DIR" ]; then \
            cp "$EXE_DIR"/* /sbbs/exec/ 2>/dev/null || true; \
        fi; \
    done

# Verify key files exist
RUN ls -la /sbbs/exec/sbbs /sbbs/exec/scfg /sbbs/exec/baja

# Build doors/external programs
WORKDIR /sbbs/src/doors
RUN for dir in */; do \
        if [ -f "$dir/Makefile" ] || [ -f "$dir/GNUmakefile" ]; then \
            make -C "$dir" RELEASE=1 2>&1 || true; \
        fi; \
    done

# Copy built door executables
RUN find /sbbs/src/doors -type f -executable -newer /sbbs/src/doors -exec file {} \; 2>/dev/null | \
    grep "ELF" | cut -d: -f1 | while read f; do \
        name=$(basename "$f"); \
        dest_dir="/sbbs/xtrn/$name"; \
        mkdir -p "$dest_dir" 2>/dev/null || true; \
        cp "$f" "$dest_dir/" 2>/dev/null || cp "$f" /sbbs/xtrn/ 2>/dev/null || true; \
    done

# Copy default config files
RUN cp -r /sbbs/ctrl.new/* /sbbs/ctrl/ 2>/dev/null || true
RUN cp -r /sbbs/text.new/* /sbbs/text/ 2>/dev/null || true

# Create required directories
RUN mkdir -p /sbbs/data /sbbs/ctrl /sbbs/text \
    /sbbs/node1 /sbbs/node2 /sbbs/node3 /sbbs/node4 \
    /sbbs/xtrn /sbbs/mods

# Create sbbs user with UID 1000 to match typical host user ownership
RUN groupadd -g 1000 sbbs && \
    useradd -u 1000 -g 1000 -d /sbbs -s /bin/bash sbbs && \
    chown -R sbbs:sbbs /sbbs

# Add entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 513 23 22 80 443 21

WORKDIR /sbbs
# Start as root, entrypoint will drop to sbbs user after bind mount
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/sbbs/exec/sbbs"]