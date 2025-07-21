#!/bin/bash
set -euo pipefail
set -x

# Test setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

# Create a spy for kubectl
KUBECTL_SPY="${TEST_DIR}/kubectl"
cat <<'EOF' > "${KUBECTL_SPY}"
#!/bin/bash
echo "KUBECTL_EXTERNAL_DIFF=${KUBECTL_EXTERNAL_DIFF}" >&2
echo "ARGS=$@" >&2
EOF
chmod +x "${KUBECTL_SPY}"

# Add spy to PATH
export PATH="${TEST_DIR}:${PATH}"

# Run kdiff in interactive mode
echo "--- Running kdiff ---"
kdiff_out=$(src/kdiff --runtime-dir "${TEST_DIR}" --yq '.spec' -- -f my-pod.yaml 2>&1 || true)
echo "--- kdiff finished ---"

# Find the preset directory
preset_dir=$(echo "${kdiff_out}" | grep 'KUBECTL_EXTERNAL_DIFF=' | sed -E 's/.*--preset (.*)/\1/')

echo "--- Assertions ---"

# Check if KUBECTL_EXTERNAL_DIFF was set correctly
if ! echo "${kdiff_out}" | grep -q "kdiff --preset"; then
  echo "FAIL: KUBECTL_EXTERNAL_DIFF was not set correctly."
  exit 1
fi
echo "PASS: KUBECTL_EXTERNAL_DIFF is set."

# Check if kubectl diff was called with the right arguments
if ! echo "${kdiff_out}" | grep -q "ARGS=diff -f my-pod.yaml"; then
  echo "FAIL: kubectl diff was not called with the correct arguments."
  exit 1
fi
echo "PASS: kubectl diff called with correct arguments."

# Check if the preset directory was created
if [[ ! -d "${preset_dir}" ]]; then
  echo "FAIL: Preset directory was not created: ${preset_dir}"
  exit 1
fi
echo "PASS: Preset directory created."

# Check the content of the transform script
transform_content=$(cat "${preset_dir}/transform")
if ! echo "${transform_content}" | grep -q "yq .spec"; then
  echo "FAIL: Transform script has wrong content."
  cat "${preset_dir}/transform"
  exit 1
fi
echo "PASS: Transform script is correct."

# Check the content of the compare script
compare_content=$(cat "${preset_dir}/compare")
if ! echo "${compare_content}" | grep -q "diff -u"; then
  echo "FAIL: Compare script has wrong content."
  cat "${preset_dir}/compare"
  exit 1
fi
echo "PASS: Compare script is correct."

echo "--- All tests passed! ---"
