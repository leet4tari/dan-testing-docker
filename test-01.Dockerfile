# syntax = docker/dockerfile:1.3

# https://hub.docker.com/_/rust
ARG RUST_VERSION=1.70

# rust source compile with cross platform build support
FROM --platform=$BUILDPLATFORM rust:$RUST_VERSION-bullseye as builder

# Declare to make available
ARG BUILDPLATFORM
ARG BUILDOS
ARG BUILDARCH
ARG BUILDVARIANT
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG RUST_TOOLCHAIN
ARG RUST_TARGET
ARG RUST_VERSION

ARG TARI_DEBUG
ARG DAN_DEBUG

# Disable anti-cache
#RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#run---mounttypecache
#RUN --mount=type=cache,id=build-apt-cache-${BUILDOS}-${BUILDARCH}${BUILDVARIANT},sharing=locked,target=/var/cache/apt \
#    --mount=type=cache,id=build-apt-lib-${BUILDOS}-${BUILDARCH}${BUILDVARIANT},sharing=locked,target=/var/lib/apt \
#  apt-get update && apt-get install -y \

# Prep nodejs 18.x
RUN apt-get update && apt-get install -y \
      apt-transport-https \
      bash \
      ca-certificates \
      curl \
      gpg && \
      curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

RUN apt-get update && apt-get install -y \
      apt-transport-https \
      bash \
      ca-certificates \
      curl \
      gpg \
      iputils-ping \
      less \
      libreadline-dev \
      libsqlite3-0 \
      openssl \
      telnet \
      cargo \
      clang \
      gcc-aarch64-linux-gnu \
      g++-aarch64-linux-gnu \
      cmake \
      nodejs \
      python3-grpc-tools

ARG ARCH=native
#ARG FEATURES=avx2
ARG FEATURES=safe
ENV RUSTFLAGS="-C target_cpu=$ARCH"
ENV ROARING_ARCH=$ARCH
ENV CARGO_HTTP_MULTIPLEXING=false

ARG VERSION=1.0.1

RUN if [ "${BUILDARCH}" != "${TARGETARCH}" ] && [ "${ARCH}" = "native" ] ; then \
      echo "!! Cross-compile and native ARCH not a good idea !! " ; \
    fi

WORKDIR /tari

ADD tari .

#RUN --mount=type=cache,id=rust-git-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/.cargo/git \
#    --mount=type=cache,id=rust-home-registry-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/.cargo/registry \
#    --mount=type=cache,id=rust-local-registry-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/usr/local/cargo/registry \
#    --mount=type=cache,id=rust-src-target-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/src/target \
#    --mount=type=cache,id=rust-target-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/tari/target \
#    if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "${TARGETARCH}" ] ; then \
RUN if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "${TARGETARCH}" ] ; then \
      # Hardcoded ARM64 envs for cross-compiling - FixMe soon
      export BUILD_TARGET="aarch64-unknown-linux-gnu/" && \
      export RUST_TARGET="--target=aarch64-unknown-linux-gnu" && \
      export ARCH=generic && \
      export FEATURES=safe && \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc && \
      export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc && \
      export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ && \
      export BINDGEN_EXTRA_CLANG_ARGS="--sysroot /usr/aarch64-linux-gnu/include/" && \
      export RUSTFLAGS="-C target_cpu=$ARCH" && \
      export ROARING_ARCH=$ARCH && \
      rustup target add aarch64-unknown-linux-gnu && \
      rustup toolchain install stable-aarch64-unknown-linux-gnu --force-non-host ; \
    fi && \
    if [ -n "${RUST_TOOLCHAIN}" ] ; then \
      # Install a non-standard toolchain if it has been requested.
      # By default we use the toolchain specified in rust-toolchain.toml
      rustup toolchain install ${RUST_TOOLCHAIN} --force-non-host ; \
    fi && \
    if [ "${TARI_DEBUG}" != "true" ] ; then \
    rustup target list --installed && \
    rustup toolchain list && \
    cargo build ${RUST_TARGET} \
      --release --features ${FEATURES} --locked \
      --bin tari_base_node \
      --bin tari_console_wallet \
      --bin tari_miner && \
    # Copy executable out of the cache so it is available in the runtime image.
    cp -v /tari/target/${BUILD_TARGET}release/tari_base_node /usr/local/bin/ && \
    cp -v /tari/target/${BUILD_TARGET}release/tari_console_wallet /usr/local/bin/ && \
    cp -v /tari/target/${BUILD_TARGET}release/tari_miner /usr/local/bin/ && \
      echo "tari debug" ; \
    fi && \
    echo "Tari Build Done"

RUN mkdir -p "/usr/local/lib/tari/protos/" && \
    python3 -m grpc_tools.protoc \
      --proto_path /tari/applications/tari_app_grpc/proto/ \
      --python_out=/usr/local/lib/tari/protos \
      --grpc_python_out=/usr/local/lib/tari/protos /tari/applications/tari_app_grpc/proto/*.proto

WORKDIR /tari-dan

ADD tari-dan .

#RUN --mount=type=cache,id=rust-git-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/.cargo/git \
#    --mount=type=cache,id=rust-home-registry-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/.cargo/registry \
#    --mount=type=cache,id=rust-local-registry-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/usr/local/cargo/registry \
#    --mount=type=cache,id=rust-src-target-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/home/rust/src/target \
#    --mount=type=cache,id=rust-target-${TARGETOS}-${TARGETARCH}${TARGETVARIANT},sharing=locked,target=/tari/target \
#    if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "${TARGETARCH}" ] ; then \
RUN if [ "${TARGETARCH}" = "arm64" ] && [ "${BUILDARCH}" != "${TARGETARCH}" ] ; then \
      # Hardcoded ARM64 envs for cross-compiling - FixMe soon
      export BUILD_TARGET="aarch64-unknown-linux-gnu/" && \
      export RUST_TARGET="--target=aarch64-unknown-linux-gnu" && \
      export ARCH=generic && \
      export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc && \
      export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc && \
      export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ && \
      export BINDGEN_EXTRA_CLANG_ARGS="--sysroot /usr/aarch64-linux-gnu/include/" && \
      export RUSTFLAGS="-C target_cpu=$ARCH" && \
      export ROARING_ARCH=$ARCH && \
      rustup target add aarch64-unknown-linux-gnu && \
      rustup toolchain install stable-aarch64-unknown-linux-gnu --force-non-host ; \
    fi && \
    if [ -n "${RUST_TOOLCHAIN}" ] ; then \
      # Install a non-standard toolchain if it has been requested.
      # By default we use the toolchain specified in rust-toolchain.toml
      rustup toolchain install ${RUST_TOOLCHAIN} --force-non-host ; \
    fi && \
    if [ "${DAN_DEBUG}" != "true" ] ; then \
    cd /tari-dan/applications/tari_indexer_web_ui && \
    npm install react-scripts && \
    npm run build && \
    cd /tari-dan/applications/tari_validator_node_web_ui && \
    npm install react-scripts && \
    npm run build && \
    cd /tari-dan/ && \
    rustup toolchain install nightly --force-non-host && \
    rustup target add wasm32-unknown-unknown && \
    rustup target add wasm32-unknown-unknown --toolchain nightly && \
    rustup default nightly-2022-11-03 && \
    rustup target list --installed && \
    rustup toolchain list && \
    rustup show && \
    cargo +nightly build ${RUST_TARGET} \
      --release --locked \
      --bin tari_indexer \
      --bin tari_dan_wallet_daemon \
      --bin tari_dan_wallet_cli \
      --bin tari_signaling_server \
      --bin tari_validator_node \
      --bin tari_validator_node_cli && \
    # Copy executable out of the cache so it is available in the runtime image.
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_indexer /usr/local/bin/ && \
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_dan_wallet_daemon /usr/local/bin/ && \
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_dan_wallet_cli /usr/local/bin/ && \
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_signaling_server /usr/local/bin/ && \
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_validator_node /usr/local/bin/ && \
    cp -v /tari-dan/target/${BUILD_TARGET}release/tari_validator_node_cli /usr/local/bin/ && \
      echo "dan debug" ; \
    fi && \
    echo "tari-dan Build Done"

# Create runtime base minimal image for the target platform executables
#FROM --platform=$TARGETPLATFORM bitnami/minideb:bullseye as runtime
FROM --platform=$BUILDPLATFORM rust:$RUST_VERSION-bullseye as runtime

ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG RUST_VERSION

ARG VERSION

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

# Prep nodejs 18.x
RUN apt-get update && apt-get install -y \
  apt-transport-https \
  bash \
  ca-certificates \
  curl \
  gpg && \
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

RUN apt-get update && apt-get --no-install-recommends install -y \
  apt-transport-https \
  bash \
  ca-certificates \
  curl \
  gpg \
  iputils-ping \
  less \
  libreadline8 \
  libreadline-dev \
  libsqlite3-0 \
  openssl \
  telnet \
  nodejs \
  python3-requests \
  python3-grpc-tools \
  python3-psutil

RUN groupadd --gid 1000 tari && \
    useradd --create-home --no-log-init --shell /bin/bash \
      --home-dir /home/tari \
      --uid 1000 --gid 1000 tari

ENV dockerfile_version=$VERSION
ENV dockerfile_build_arch=$BUILDPLATFORM
ENV rust_version=$RUST_VERSION

RUN mkdir -p "/home/tari/sources/tari-connector" && \
    mkdir -p "/home/tari/sources/dan-testing/Data" && \
    mkdir -p "/home/tari/sources/tari" && \
    mkdir -p "/home/tari/sources/tari-dan" && \
    chown -R tari:tari "/home/tari/" && \
    mkdir -p "/usr/local/lib/tari/protos" && \
    ln -vsf "/home/tari/sources/tari-connector/" "/usr/lib/node_modules/tari-connector" && \
    mkdir -p "/usr/local/lib/node_modules" && \
    chown -R tari:tari "/usr/local/lib/node_modules"

USER tari

WORKDIR /home/tari
RUN cargo install cargo-generate

WORKDIR /home/tari/sources
#ADD tari tari
#ADD tari-dan tari-dan
ADD tari-connector tari-connector
ADD dan-testing dan-testing

WORKDIR /home/tari/sources/tari-connector
RUN npm link

WORKDIR /home/tari/sources/dan-testing
RUN npm link tari-connector

COPY --from=builder /usr/local/bin/tari_* /usr/local/bin/
#COPY --from=builder /usr/local/lib/tari/protos /usr/local/lib/tari/protos
COPY --from=builder /usr/local/lib/tari/protos /home/tari/sources/dan-testing/protos

ENV DAN_TESTING_USE_BINARY_EXECUTABLE=True
WORKDIR /home/tari/sources/dan-testing
#ENTRYPOINT [ "tari_base_node" ]
#CMD [ "--non-interactive-mode" ]
#CMD [ "python3", "main.py"]
CMD [ "tail", "-f", "/dev/null" ]
