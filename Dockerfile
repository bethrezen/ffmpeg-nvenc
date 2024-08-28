# syntax=docker/dockerfile:1
#FROM debian:11-slim
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04 as builder
#AS builder
MAINTAINER Alexander Kozhevnikov
#
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all
ENV DEBIAN_FRONTEND noninterac1tive
ENV FFMPEG_VERSION 6.1.2
#
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
#
#
WORKDIR /app
#
## Prepare
RUN sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list \
    && apt-get -q  update
RUN apt-get install -y \
    curl diffutils file coreutils m4 xz-utils nasm python3 python3-pip appstream
#
## Install dependencies
RUN apt-get install -y \
    autoconf automake build-essential cmake git libass-dev libbz2-dev libfontconfig1-dev libfreetype6-dev libfribidi-dev \
    libharfbuzz-dev libjansson-dev liblzma-dev libmp3lame-dev libnuma-dev libogg-dev libopus-dev libsamplerate-dev \
    libspeex-dev libtheora-dev libtool libtool-bin libturbojpeg0-dev libvorbis-dev libx264-dev libxml2-dev libvpx-dev \
    m4 make nasm ninja-build patch pkg-config tar zlib1g-dev autopoint imagemagick gsfonts wget \
    libx265-dev libfdk-aac-dev librtmp-dev libwebp-dev libssl-dev checkinstall
#
## Intel CSV dependencies
#RUN apt-get install -y libva-dev libdrm-dev
#   
#
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git \
	&& cd nv-codec-headers \
	&& make -j$(nproc) \
	&& make install
#
RUN wget https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz \
 && tar -xf ffmpeg-${FFMPEG_VERSION}.tar.xz \
 && rm ffmpeg-${FFMPEG_VERSION}.tar.xz

#
#RUN  cd ffmpeg-${FFMPEG_VERSION} && ./configure --help && exit 1
# Configure and build ffmpeg with nvenc support
RUN cd ffmpeg-${FFMPEG_VERSION} \
 && ./configure --prefix=/usr/local \
    --enable-version3 \
    --enable-avdevice \
        --enable-gpl \
        --enable-nonfree \
        --enable-small \
        --enable-libmp3lame \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libopus \
        --enable-libfdk-aac \
        --enable-libass \
        --enable-libwebp \
        --enable-librtmp \
        --enable-postproc \
        --enable-libfreetype \
        --enable-openssl \
        --enable-avfilter \
        --enable-pic \
        --enable-shared \
        --enable-pthreads \
        --enable-nvenc \
        --enable-cuda \
        --enable-cuvid \
        --enable-libnpp \
        --disable-stripping \
        --enable-static \
         --enable-shared \
        --disable-debug \
    --cc=gcc \
    --enable-fontconfig \
    --enable-gray \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64
RUN  cd ffmpeg-${FFMPEG_VERSION} && make -j16
RUN cd ffmpeg-${FFMPEG_VERSION} && checkinstall \
          --default \
          --install=no \
          --nodoc \
          --pakdir=/tmp/packages \
          --pkgname=ffmpeg \
          --pkgversion=$FFMPEG_VERSION \
          --type=debian \
            make install
RUN ls -la /tmp/packages
RUN cd ffmpeg-${FFMPEG_VERSION} && make install -j$(nproc)

ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib"
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04
##
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES all
ENV DEBIAN_FRONTEND noninterac1tive
ENV FFMPEG_VERSION 6.1.2
##
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib"
RUN apt update -q
COPY --from=builder /tmp/packages /tmp/packages
RUN apt-get install -y \
    libass9 \
    libavcodec-extra58 \
    libavfilter-extra7 \
    libavformat58 \
    libavutil56 \
    libbluray2 \
    libc6 \
    libcairo2 \
    libdvdnav4 \
    libdvdread8 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libgstreamer1.0-0 \
    libgtk-3-0 \
    libgudev-1.0-0 \
    libjansson4 \
    libpango-1.0-0 \
    libsamplerate0 \
    libswresample3 \
    libswscale5 \
    libtheora0 \
    libvorbis0a \
    libvorbisenc2 \
    libx264-163 \
    libx265-199 \
    libxml2 \
    libturbojpeg \
    librtmp1 \
    libfdk-aac2

RUN dpkg -i /tmp/packages/*
RUN ffmpeg -version