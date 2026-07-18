#!/usr/bin/env bash
#
# mayhem/test.sh — run reliable's upstream test suite (built by mayhem/build.sh).
# Counts the 14 unit tests inside build-tests/bin/test individually (behavioral:
# each RUN_TEST prints its name and the run must end with "*** ALL TESTS PASSED ***"),
# plus the three other ctest programs (fuzz, soak, fuzz_target standalone driver).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

PASS=0; FAIL=0

UNIT_TESTS=(test_endian test_sequence_buffer test_generate_ack_bits test_packet_header
  test_acks test_acks_packet_loss test_duplicate_packets test_stale_packets
  test_ack_buffer_overflow test_packets test_large_packets test_sequence_buffer_rollover
  test_fragment_cleanup test_endpoint_reset)

TESTBIN=build-tests/bin/test
if [ ! -x "$TESTBIN" ]; then
  echo "FATAL: $TESTBIN missing — mayhem/build.sh did not build the test suite" >&2
  emit_ctrf "cmake-ctest" 0 $(( ${#UNIT_TESTS[@]} + 3 ))
  exit 1
fi

out="$("$TESTBIN" 2>&1)"; rc=$?
for t in "${UNIT_TESTS[@]}"; do
  if [ $rc -eq 0 ] && grep -qx "$t" <<<"$out" && grep -q '\*\*\* ALL TESTS PASSED \*\*\*' <<<"$out"; then
    PASS=$((PASS+1))
  else
    echo "UNIT FAIL: $t" >&2; FAIL=$((FAIL+1))
  fi
done

# The remaining ctest programs: bounded fuzz run, soak run, standalone fuzz_target driver.
for spec in "fuzz:shutdown:build-tests/bin/fuzz 20000 12345" \
            "soak:shutdown:build-tests/bin/soak 8192 --quiet" \
            "fuzz_target:passed:build-tests/bin/fuzz_target_standalone 500 12345"; do
  name="${spec%%:*}"; rest="${spec#*:}"; marker="${rest%%:*}"; cmd="${rest#*:}"
  if pout="$($cmd 2>&1)" && grep -q "$marker" <<<"$pout"; then
    PASS=$((PASS+1))
  else
    echo "CTEST FAIL: $name" >&2; FAIL=$((FAIL+1))
  fi
done

emit_ctrf "cmake-ctest" "$PASS" "$FAIL"
