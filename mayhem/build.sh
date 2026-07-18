#!/usr/bin/env bash
#
# mayhem/build.sh — build the reliable fuzz harnesses + the upstream test suite.
#
# Fuzz targets (sanitized, DWARF-3):
#   /mayhem/reliable_fuzz         <- mayhem/fuzz_packet.c (historical Mayhem target "reliable-fuzz")
#   /mayhem/reliable_fuzz_target  <- fuzz_target.c (upstream's OSS-Fuzz libFuzzer harness)
# plus a *-standalone run-once reproducer for each.
#
# Test suite: upstream CMake build (normal flags) into build-tests/, run by mayhem/test.sh.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1) Sanitized + DWARF-3 build of the library itself (the fuzzed code must be instrumented).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. -c reliable.c -o /tmp/reliable_san.o

# 2) Each harness twice: libFuzzer binary + standalone run-once reproducer.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. $LIB_FUZZING_ENGINE \
    "$SRC/mayhem/fuzz_packet.c" /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. $LIB_FUZZING_ENGINE \
    "$SRC/fuzz_target.c" /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz_target

$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. \
    "$SRC/mayhem/fuzz_packet.c" /tmp/standalone_main.o /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz-standalone
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. \
    "$SRC/fuzz_target.c" /tmp/standalone_main.o /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz_target-standalone

# 3) Upstream test suite with normal flags (test.sh only RUNS it).
cmake -B build-tests -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build-tests -j"$MAYHEM_JOBS"
