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
    wget \
    autoconf2.13 \
    && rm -rf /var/lib/apt/lists/*

# NOTE: We do NOT install libmozjs-78-dev - it's broken on ARM64!
# Instead, Synchronet will build its bundled SpiderMonkey 1.8.5

# Clone Synchronet
RUN git clone --depth 1 https://gitlab.synchro.net/main/sbbs.git /sbbs

# Fix ARM64 build: Update config.guess and config.sub in mozjs source
# The bundled versions are from 2009 and don't recognize aarch64
RUN wget -q -O /tmp/config.guess 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD' && \
    wget -q -O /tmp/config.sub 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD' && \
    chmod +x /tmp/config.guess /tmp/config.sub && \
    find /sbbs -name "config.guess" -exec cp /tmp/config.guess {} \; && \
    find /sbbs -name "config.sub" -exec cp /tmp/config.sub {} \;

# Build Synchronet (this will compile the bundled SpiderMonkey)
WORKDIR /sbbs/src/sbbs3
ENV SBBSDIR=/sbbs
RUN make RELEASE=1 SBBSDIR=/sbbs 2>&1 | tee /tmp/build.log || \
    (echo "=== BUILD FAILED - Last 200 lines ===" && tail -200 /tmp/build.log && exit 1)

# Install all binaries to exec directory
RUN find /sbbs/src -path "*/gcc.linux.*.exe.release/*" -type f -executable -exec cp {} /sbbs/exec/ \; 2>/dev/null || true

# Copy shared libraries to exec directory
RUN find /sbbs/src -path "*/gcc.linux.*.lib.release/*.so" -exec cp {} /sbbs/exec/ \; 2>/dev/null || true

RUN ls -la /sbbs/exec/sbbs /sbbs/exec/scfg /sbbs/exec/*.so

# Copy default config files
RUN cp -r /sbbs/ctrl.new/* /sbbs/ctrl/ 2>/dev/null || true
RUN cp -r /sbbs/text.new/* /sbbs/text/ 2>/dev/null || true

RUN ls -la /sbbs/exec/sbbs

# Create required directories
RUN mkdir -p /sbbs/data /sbbs/ctrl /sbbs/text /sbbs/node1 /sbbs/node2 /sbbs/node3 /sbbs/node4

# Add entrypoint (your existing one with bind mount password injection)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 513 23 22 80 443 21

WORKDIR /sbbs
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/sbbs/exec/sbbs"]