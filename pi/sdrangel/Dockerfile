# SDRAngel ARM64 Debian Package Builder
# Builds SDRAngel for Raspberry Pi (arm64/aarch64) on Apple Silicon Mac
#
# Based on official build instructions from:
# https://github.com/f4exb/sdrangel/wiki/Compile-from-source-in-Linux
#
# Usage:
#   docker build --platform linux/arm64 -t sdrangel-builder .
#   docker run --platform linux/arm64 -v $(pwd)/output:/output sdrangel-builder
#
# The .deb file will be in ./output/

FROM debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG SDRANGEL_VERSION=7.22.0

# Install ALL build dependencies from official documentation
# https://github.com/f4exb/sdrangel/wiki/Compile-from-source-in-Linux
RUN apt-get update && apt-get -y install \
    git \
    cmake \
    g++ \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libfftw3-dev \
    libusb-1.0-0-dev \
    libusb-dev \
    libhidapi-dev \
    libopengl-dev \
    # Qt5 packages
    qtbase5-dev \
    qtchooser \
    libqt5multimedia5-plugins \
    qtmultimedia5-dev \
    libqt5websockets5-dev \
    qttools5-dev \
    qttools5-dev-tools \
    libqt5opengl5-dev \
    libqt5quick5 \
    libqt5charts5-dev \
    qml-module-qtlocation \
    qml-module-qtpositioning \
    qml-module-qtquick-window2 \
    qml-module-qtquick-dialogs \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    libqt5serialport5-dev \
    qtdeclarative5-dev \
    qtpositioning5-dev \
    qtlocation5-dev \
    libqt5texttospeech5-dev \
    qtwebengine5-dev \
    qtbase5-private-dev \
    libqt5gamepad5-dev \
    libqt5svg5-dev \
    # Audio and codecs
    libfaad-dev \
    libflac-dev \
    zlib1g-dev \
    libboost-all-dev \
    libasound2-dev \
    pulseaudio \
    libopus-dev \
    libspeexdsp-dev \
    libsamplerate0-dev \
    # Video/image processing
    libopencv-dev \
    libxml2-dev \
    bison \
    flex \
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    # SDR hardware libraries (from Debian repos)
    librtlsdr-dev \
    libhackrf-dev \
    libairspy-dev \
    libairspyhf-dev \
    libiio-dev \
    libad9361-dev \
    libsoapysdr-dev \
    libbladerf-dev \
    liblimesuite-dev \
    libuhd-dev \
    libhamlib-dev \
    # For building .deb packages
    devscripts \
    fakeroot \
    debhelper \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/build

# ============================================================================
# NON-HARDWARE DEPENDENCIES (from official docs)
# ============================================================================

# Build APTdec
RUN git clone https://github.com/srcejon/aptdec.git && \
    cd aptdec && \
    git checkout libaptdec && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/aptdec .. && \
    make -j4 install

# Build CM256cc
RUN git clone https://github.com/f4exb/cm256cc.git && \
    cd cm256cc && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/cm256cc .. && \
    make -j4 install

# Build LibDAB
RUN git clone https://github.com/srcejon/dab-cmdline && \
    cd dab-cmdline/library && \
    git checkout msvc && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/libdab .. && \
    make -j4 install

# Build MBElib
RUN git clone https://github.com/szechyjs/mbelib.git && \
    cd mbelib && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/mbelib .. && \
    make -j4 install

# Build SerialDV
RUN git clone https://github.com/f4exb/serialDV.git && \
    cd serialDV && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/serialdv .. && \
    make -j4 install

# Build DSDcc
RUN git clone https://github.com/f4exb/dsdcc.git && \
    cd dsdcc && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/dsdcc \
          -DUSE_MBELIB=ON \
          -DLIBMBE_INCLUDE_DIR=/opt/install/mbelib/include \
          -DLIBMBE_LIBRARY=/opt/install/mbelib/lib/libmbe.so \
          -DLIBSERIALDV_INCLUDE_DIR=/opt/install/serialdv/include/serialdv \
          -DLIBSERIALDV_LIBRARY=/opt/install/serialdv/lib/libserialdv.so .. && \
    make -j4 install

# Build Codec2
RUN git clone https://github.com/drowe67/codec2-dev.git codec2 && \
    cd codec2 && \
    mkdir build_linux && cd build_linux && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/codec2 .. && \
    make -j4 install

# Build SGP4
RUN git clone https://github.com/dnwrnr/sgp4.git && \
    cd sgp4 && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/sgp4 .. && \
    make -j4 install

# Build LibSigMF
RUN git clone https://github.com/f4exb/libsigmf.git && \
    cd libsigmf && \
    git checkout new-namespaces && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/libsigmf .. && \
    make -j4 install

# Build GGMorse
RUN git clone https://github.com/ggerganov/ggmorse.git && \
    cd ggmorse && \
    mkdir build && cd build && \
    cmake -Wno-dev -DCMAKE_INSTALL_PREFIX=/opt/install/ggmorse \
          -DGGMORSE_BUILD_TESTS=OFF \
          -DGGMORSE_BUILD_EXAMPLES=OFF .. && \
    make -j4 install

# ============================================================================
# BUILD SDRANGEL
# ============================================================================

RUN git clone https://github.com/f4exb/sdrangel.git && \
    cd sdrangel && \
    mkdir build && cd build && \
    cmake -Wno-dev -DDEBUG_OUTPUT=OFF -DRX_SAMPLE_24BIT=ON \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/opt/install/sdrangel \
          -DAPT_DIR=/opt/install/aptdec \
          -DCM256CC_DIR=/opt/install/cm256cc \
          -DDAB_DIR=/opt/install/libdab \
          -DDSDCC_DIR=/opt/install/dsdcc \
          -DSERIALDV_DIR=/opt/install/serialdv \
          -DMBE_DIR=/opt/install/mbelib \
          -DCODEC2_DIR=/opt/install/codec2 \
          -DSGP4_DIR=/opt/install/sgp4 \
          -DLIBSIGMF_DIR=/opt/install/libsigmf \
          -DGGMORSE_DIR=/opt/install/ggmorse \
          .. && \
    make -j4 && \
    make install

# ============================================================================
# CREATE .DEB PACKAGE
# ============================================================================

RUN mkdir -p /package/sdrangel_${SDRANGEL_VERSION}_arm64/DEBIAN && \
    mkdir -p /package/sdrangel_${SDRANGEL_VERSION}_arm64/opt && \
    mkdir -p /package/sdrangel_${SDRANGEL_VERSION}_arm64/usr/local/bin && \
    mkdir -p /package/sdrangel_${SDRANGEL_VERSION}_arm64/usr/share/applications && \
    mkdir -p /package/sdrangel_${SDRANGEL_VERSION}_arm64/etc/ld.so.conf.d

# Copy installed files
RUN cp -r /opt/install/* /package/sdrangel_${SDRANGEL_VERSION}_arm64/opt/

# Create control file
RUN echo "Package: sdrangel\n\
Version: ${SDRANGEL_VERSION}\n\
Section: hamradio\n\
Priority: optional\n\
Architecture: arm64\n\
Depends: libqt5core5a, libqt5gui5, libqt5widgets5, libqt5multimedia5, libqt5websockets5, libqt5serialport5, libqt5charts5, libqt5texttospeech5, libqt5quick5, libqt5positioning5, libqt5location5, libgl1, libpulse0, libfaad2, libflac8, libopus0, libspeexdsp1, libfftw3-single3, libavcodec59 | libavcodec-extra59, libavformat59, libswscale6, libusb-1.0-0, librtlsdr0, libhackrf0, libairspy0, libairspyhf1, libiio0, libad9361-0, libsoapysdr0.8, libhamlib4, libopencv-core406 | libopencv-core4.5d, libhidapi-libusb0, libsamplerate0\n\
Maintainer: Ansible Pi Setup\n\
Description: SDRAngel - SDR Rx/Tx software\n\
 SDR Rx/Tx software for Airspy, Airspy HF+, BladeRF, HackRF,\n\
 LimeSDR, PlutoSDR, RTL-SDR, SDRplay and FunCube.\n\
 Built for Raspberry Pi (arm64/aarch64).\n" > /package/sdrangel_${SDRANGEL_VERSION}_arm64/DEBIAN/control

# Create postinst script
RUN echo '#!/bin/bash\nldconfig\n' > /package/sdrangel_${SDRANGEL_VERSION}_arm64/DEBIAN/postinst && \
    chmod 755 /package/sdrangel_${SDRANGEL_VERSION}_arm64/DEBIAN/postinst

# Create ld.so.conf.d file for library paths
RUN echo "/opt/sdrangel/lib\n\
/opt/aptdec/lib\n\
/opt/cm256cc/lib\n\
/opt/libdab/lib\n\
/opt/dsdcc/lib\n\
/opt/serialdv/lib\n\
/opt/mbelib/lib\n\
/opt/codec2/lib\n\
/opt/sgp4/lib\n\
/opt/libsigmf/lib\n\
/opt/ggmorse/lib\n" > /package/sdrangel_${SDRANGEL_VERSION}_arm64/etc/ld.so.conf.d/sdrangel.conf

# Create launcher script
RUN echo '#!/bin/bash\n\
export LD_LIBRARY_PATH=/opt/sdrangel/lib:/opt/aptdec/lib:/opt/cm256cc/lib:/opt/libdab/lib:/opt/dsdcc/lib:/opt/serialdv/lib:/opt/mbelib/lib:/opt/codec2/lib:/opt/sgp4/lib:/opt/libsigmf/lib:/opt/ggmorse/lib:$LD_LIBRARY_PATH\n\
exec /opt/sdrangel/bin/sdrangel "$@"\n' > /package/sdrangel_${SDRANGEL_VERSION}_arm64/usr/local/bin/sdrangel && \
    chmod 755 /package/sdrangel_${SDRANGEL_VERSION}_arm64/usr/local/bin/sdrangel

# Create desktop entry
RUN echo "[Desktop Entry]\n\
Name=SDRAngel\n\
Comment=SDR Rx/Tx Software\n\
Exec=sdrangel\n\
Icon=sdrangel\n\
Terminal=false\n\
Type=Application\n\
Categories=Network;HamRadio;\n" > /package/sdrangel_${SDRANGEL_VERSION}_arm64/usr/share/applications/sdrangel.desktop

# Build the .deb package
RUN cd /package && \
    dpkg-deb --build sdrangel_${SDRANGEL_VERSION}_arm64

# Copy to output on run
CMD cp /package/*.deb /output/ && \
    echo "Built: $(ls /package/*.deb)" && \
    echo "Package copied to /output/"