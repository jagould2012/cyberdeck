FROM arm64v8/node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for ENiGMA and DOSBox-X build
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    dos2unix \
    unzip \
    wget \
    git \
    libvips-dev \
    automake \
    libncurses-dev \
    nasm \
    libsdl2-dev \
    libsdl2-net-dev \
    libpcap-dev \
    libslirp-dev \
    libfluidsynth-dev \
    libavformat-dev \
    libavcodec-dev \
    libswscale-dev \
    libfreetype-dev \
    libxkbfile-dev \
    libxrandr-dev \
    libglu1-mesa-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Build DOSBox-X from source (ARM64 native)
RUN git clone https://github.com/joncampbell123/dosbox-x.git /tmp/dosbox-x \
    && cd /tmp/dosbox-x \
    && ./build-debug \
    && make install \
    && rm -rf /tmp/dosbox-x

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

RUN for i in 1 2 3 4 5 6 7 8 9 10; do \
    mkdir -p /enigma-bbs/doors/dropfiles/node$i; \
    done

# Create bbs user for door games
RUN useradd -m -s /bin/bash bbs

# Copy door scripts to a separate location (not in the volume mount)
COPY scripts/lord.sh /usr/local/bin/lord.sh
COPY scripts/tw2002.sh /usr/local/bin/tw2002.sh
RUN chmod +x /usr/local/bin/*.sh

# Install xvfb for headless DOSBox-X
RUN apt-get update && apt-get install -y xvfb && rm -rf /var/lib/apt/lists/*

# Save defaults before volumes mount over them
RUN mkdir -p /enigma-bbs-defaults && \
    cp -r /enigma-bbs/mods /enigma-bbs-defaults/mods && \
    cp -r /enigma-bbs/art /enigma-bbs-defaults/art

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /enigma-bbs
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "main.js"]