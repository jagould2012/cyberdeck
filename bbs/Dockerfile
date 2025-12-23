FROM arm64v8/debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js and dependencies
RUN apt-get update && apt-get install -y \
    curl \
    python3 \
    build-essential \
    dos2unix \
    unzip \
    wget \
    git \
    libvips-dev \
    cmake \
    gcc-arm-linux-gnueabihf \
    libc6-armhf-cross \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Box86 (x86 emulator for ARM)
RUN git clone https://github.com/ptitSeb/box86.git /tmp/box86 \
    && cd /tmp/box86 \
    && mkdir build && cd build \
    && cmake .. -DARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/box86

# Install 32-bit x86 libraries for Box86
RUN dpkg --add-architecture armhf \
    && apt-get update \
    && apt-get install -y libc6:armhf libstdc++6:armhf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download x86 DOSBox-X for doors
RUN wget -O /tmp/dosbox-x.tar.xz https://github.com/joncampbell123/dosbox-x/releases/download/dosbox-x-v2024.10.01/dosbox-x-linux-x86-2024.10.01.tar.xz \
    && mkdir -p /opt/dosbox-x \
    && tar -xf /tmp/dosbox-x.tar.xz -C /opt/dosbox-x --strip-components=1 \
    && rm /tmp/dosbox-x.tar.xz \
    && ln -s /opt/dosbox-x/bin/x86/dosbox-x /usr/local/bin/dosbox-x

# Create bbs user
RUN useradd -m -s /bin/bash bbs

# Clone ENiGMA BBS
RUN git clone https://github.com/NuSkooler/enigma-bbs.git /enigma-bbs

# Apply sharp fix - load sharp before sqlite3 to prevent ARM64 segfault
RUN sed -i '2a\\n// WORKAROUND: Load sharp before sqlite3 to prevent ARM64 segfault\ntry { require('\''sharp'\''); } catch(e) { /* sharp is optional */ }\n' /enigma-bbs/main.js

# Install ENiGMA dependencies
RUN cd /enigma-bbs && \
    npm pkg delete scripts.prepare && \
    npm install --omit=dev

# Create directory structure for doors
RUN mkdir -p /enigma-bbs/doors/lord \
    && mkdir -p /enigma-bbs/doors/tw2002 \
    && mkdir -p /enigma-bbs/doors/dropfiles

# Create node directories for dropfiles
RUN for i in 1 2 3 4 5 6 7 8 9 10; do \
    mkdir -p /enigma-bbs/doors/dropfiles/node$i; \
    done

# Copy door scripts
COPY scripts/lord.sh /enigma-bbs/doors/lord.sh
COPY scripts/tw2002.sh /enigma-bbs/doors/tw2002.sh
RUN chmod +x /enigma-bbs/doors/*.sh

# Set ownership
RUN chown -R bbs:bbs /enigma-bbs/doors

WORKDIR /enigma-bbs
CMD ["node", "main.js"]