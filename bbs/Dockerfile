FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV SBBSCTRL=/sbbs/ctrl
ENV SBBSEXEC=/sbbs/exec
ENV LD_LIBRARY_PATH=/sbbs/exec
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
    && rm -rf /var/lib/apt/lists/*

# Clone Synchronet (full clone for doors/xtrn)
RUN git clone --depth 1 https://gitlab.synchro.net/main/sbbs.git /sbbs

# Build main Synchronet
WORKDIR /sbbs/src/sbbs3
ENV SBBSDIR=/sbbs
RUN make RELEASE=1 SBBSDIR=/sbbs 2>&1 && \
    echo "=== Main build completed ==="

# Install all binaries to exec directory
RUN find /sbbs/src -path "*/gcc.linux.*.exe.release/*" -type f -executable -exec cp {} /sbbs/exec/ \; && \
    find /sbbs/src -path "*/gcc.linux.*.lib.release/*.so" -exec cp {} /sbbs/exec/ \;

# Build doors/external programs
WORKDIR /sbbs/src/doors
RUN for dir in */; do \
        if [ -f "$dir/Makefile" ] || [ -f "$dir/GNUmakefile" ]; then \
            echo "Building door: $dir"; \
            make -C "$dir" RELEASE=1 2>&1 || true; \
        fi; \
    done && \
    echo "=== Doors build completed ==="

# Copy built door executables to xtrn directories
RUN find /sbbs/src/doors -type f -executable -newer /sbbs/src/doors -exec file {} \; | \
    grep "ELF" | cut -d: -f1 | while read f; do \
        name=$(basename "$f"); \
        dest_dir="/sbbs/xtrn/$name"; \
        mkdir -p "$dest_dir" 2>/dev/null || true; \
        cp "$f" "$dest_dir/" 2>/dev/null || cp "$f" /sbbs/xtrn/ 2>/dev/null || true; \
    done

# Build Baja scripts (.src -> .bin)
WORKDIR /sbbs/exec
RUN for src in *.src; do \
        if [ -f "$src" ]; then \
            echo "Compiling: $src"; \
            /sbbs/exec/baja "$src" 2>&1 || true; \
        fi; \
    done && \
    echo "=== Baja compilation completed ==="

# Also compile any .src files in xtrn subdirectories
RUN find /sbbs/xtrn -name "*.src" -type f | while read src; do \
        echo "Compiling: $src"; \
        /sbbs/exec/baja "$src" 2>&1 || true; \
    done

# Copy default config files
RUN cp -r /sbbs/ctrl.new/* /sbbs/ctrl/ 2>/dev/null || true
RUN cp -r /sbbs/text.new/* /sbbs/text/ 2>/dev/null || true

# Verify key files exist
RUN ls -la /sbbs/exec/sbbs /sbbs/exec/scfg /sbbs/exec/baja && \
    echo "=== Checking for compiled .bin files ===" && \
    ls -la /sbbs/exec/*.bin 2>/dev/null | head -10 || echo "No .bin files yet"

# Create required directories
RUN mkdir -p /sbbs/data /sbbs/ctrl /sbbs/text \
    /sbbs/node1 /sbbs/node2 /sbbs/node3 /sbbs/node4 \
    /sbbs/xtrn /sbbs/mods

# Add entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 513 23 22 80 443 21

WORKDIR /sbbs
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/sbbs/exec/sbbs"]