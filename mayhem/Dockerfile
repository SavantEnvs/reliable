# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
#RUN apt-get update && \
#    DEBIAN_FRONTEND=noninteractive apt-get install -y git clang make build-essential

## Install premake5 (prebuilt binary)

## Add source code to the build stage. ADD prevents git clone being cached when it shouldn't
WORKDIR /
ADD https://api.github.com/repos/capuanob/reliable/git/refs/heads/mayhem version.json
RUN git clone -b mayhem https://github.com/capuanob/reliable.git
WORKDIR /reliable


## Build
RUN ./premake5 gmake2 
RUN CC=clang CFLAGS=-fsanitize=address,fuzzer LDFLAGS=-fsanitize=address,fuzzer make mayhem

## Prepare all library dependencies for copy
RUN mkdir /deps
RUN cp `ldd ./bin/mayhem | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :

## Package Stage
FROM --platform=linux/amd64 ubuntu:20.04
COPY --from=builder /reliable/bin/mayhem /mayhem
COPY --from=builder /deps /usr/lib

CMD ["/mayhem"]
