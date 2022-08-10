# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y clang make build-essential wget

## Install premake5 (prebuilt binary)
WORKDIR /
RUN wget https://github.com/premake/premake-core/releases/download/v5.0.0-beta1/premake-5.0.0-beta1-linux.tar.gz
RUN tar xf premake-5.0.0-beta1-linux.tar.gz

ADD . /reliable
WORKDIR /reliable

## Build
RUN /premake5 gmake2
RUN CC=clang CFLAGS=-fsanitize=address,fuzzer LDFLAGS=-fsanitize=address,fuzzer make reliable_fuzz

## Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
COPY --from=builder /reliable/bin/reliable_fuzz /reliable_fuzz
