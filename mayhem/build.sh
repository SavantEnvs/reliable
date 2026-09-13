#!/usr/bin/env bash
#
# mayhem/build.sh — build the reliable fuzz harness + the upstream test suite.
#
# Fuzz target (sanitized, DWARF-3):
#   /mayhem/reliable_fuzz  <- mayhem/fuzz_packet.c (historical Mayhem target "reliable-fuzz")
# plus a *-standalone run-once reproducer.
#
# At this UPSTREAM revision there is no fuzz_target.c and no CMakeLists.txt yet (both land in
# a later upstream commit) — the repo still builds via premake5.lua. The test suite here is a
# single unity TU (test.cpp #include's reliable.c itself), and fuzz.c/soak.c are upstream's own
# equivalents of the fuzz harness, run by mayhem/test.sh as functional/soak checks.
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

# 2) The harness twice: libFuzzer binary + standalone run-once reproducer.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. $LIB_FUZZING_ENGINE \
    "$SRC/mayhem/fuzz_packet.c" /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz

$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -O1 -DRELIABLE_DEBUG -I. \
    "$SRC/mayhem/fuzz_packet.c" /tmp/standalone_main.o /tmp/reliable_san.o -lm -o /mayhem/reliable_fuzz-standalone

# 3) Upstream test suite (test.sh only RUNS these): unity-build unit tests, plus fuzz/soak as
#    ctest-style functional checks. Normal (unsanitized) flags — COVERAGE_FLAGS only, as before.
mkdir -p build-tests/bin
$CXX $COVERAGE_FLAGS -O1 -I. test.cpp -lm -o build-tests/bin/test
$CC $COVERAGE_FLAGS -O1 -I. fuzz.c reliable.c -lm -o build-tests/bin/fuzz
$CC $COVERAGE_FLAGS -O1 -I. soak.c reliable.c -lm -o build-tests/bin/soak
