FROM node:22-bookworm

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    build-essential \
    dos2unix \
    unzip \
    wget \
    git \
    libvips-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone and install ENiGMA BBS
RUN git clone https://github.com/NuSkooler/enigma-bbs.git /enigma-bbs && \
    cd /enigma-bbs && \
    npm pkg delete scripts.prepare && \
    npm install --omit=dev

# Create directory structure
RUN mkdir -p /enigma-bbs/doors/lord \
    && mkdir -p /enigma-bbs/doors/tw2002 \
    && mkdir -p /enigma-bbs/doors/dropfiles

RUN for i in 1 2 3 4 5 6 7 8 9 10; do \
    mkdir -p /enigma-bbs/doors/dropfiles/node$i; \
    done

WORKDIR /enigma-bbs
CMD ["node", "main.js"]