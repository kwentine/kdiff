#!/bin/bash

testlog() {
  echo "TEST: $*"
}

# kdiff integration test suite
setup_test_env() {
  KDIFF_ROOT="$(git rev-parse --show-toplevel)"
  declare -rg KDIFF_ROOT

  # Directory with fake data
  export KDIFF_TEST_FIXTURES="${KDIFF_ROOT}/tests/fixtures"
  # Directory with mock kubectl
  export KDIFF_TEST_BIN="${KDIFF_ROOT}/tests/bin"
  # Modify path so that 'kdiff' and mock 'kubectl' are found
  export PATH="${KDIFF_ROOT}/bin:${KDIFF_TEST_BIN}:${PATH}"

  export KDIFF_CONFIG_DIR="${KDIFF_ROOT}/presets"
  export KDIFF_RUNTIME_DIR="${KDIFF_ROOT}/tests/run"
  export KDIFF_TMP_DIR="${KDIFF_ROOT}/tests/tmp"
}

xkubectl() {
  testlog "(skipped)"
}

test_internal_call() {
  testlog "Testing KUBECTL_EXTERNAL_DIFF=kdiff"

  testlog "(no arguments)"
  export KUBECTL_EXTERNAL_DIFF=kdiff
  kubectl > /dev/null

  testlog "kdiff --preset default"
  export KUBECTL_EXTERNAL_DIFF="kdiff --preset default"
  kubectl > /dev/null

  testlog "kdiff --preset=cleany"
  export KUBECTL_EXTERNAL_DIFF="kdiff --preset=cleany"
  kubectl >/dev/null
  return 0
}

xtest_internal_call() {
  :
}

test_interactive_call () {
  testlog "Testing kiff called interactively"
  testlog "(no arguments)"
  kdiff -- -f foo.yaml > /dev/null

  testlog "--preset clean:dyff"
  kdiff --preset default -- -f foo.yaml > /dev/null
  return 0
}


if ! setup_test_env; then
  echo "ERROR: Could not setup test environment"
  exit 1
fi

xtest_internal_call
test_interactive_call
