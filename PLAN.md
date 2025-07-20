# kdiff Implementation Plan

This plan outlines the steps to complete the `src/kdiff` script. We will proceed in small, incremental steps, focusing on one function at a time.

## Phase 1: Core Logic and Interactive Mode (Done)

1.  **Complete `parse_args`:**
    *   Robustly detect whether the script is run interactively or as `KUBECTL_EXTERNAL_DIFF`. A simple way is to check if the arguments look like file paths. If `$1` and `$2` are directories, it's likely an internal call. Otherwise, it's interactive.
    *   Set the `interactive` variable correctly.

2.  **Implement `create_staging_dir`:**
    *   This function is almost complete. Just needs to correctly return the created directory path.

3.  **Implement `compile_transform` and `compile_compare`:**
    *   These functions are responsible for creating the `transform` and `compare` scripts within a preset directory.
    *   `compile_transform`: Correctly handle the `yq_expr` and `transform` variables to generate the script.
    *   `compile_compare`: Correctly handle the `compare` variable and `KUBECTL_EXTERNAL_DIFF` fallback.

4.  **Implement `create_runtime_preset`:**
    *   This function will use `compile_transform` and `compile_compare` to create a complete runtime preset.

5.  **Implement `handle_interactive_call`:**
    *   This is the core of the interactive mode.
    *   It should call `create_runtime_preset` to create a temporary preset.
    *   It should then set `KUBECTL_EXTERNAL_DIFF` to `kdiff --preset <runtime_preset_path>`.
    *   Finally, it should execute `kubectl diff` with the user-provided arguments.

6.  **Refine `main` function for interactive flow:**
    *   Update the `main` function to call `handle_interactive_call` when `interactive` is true.

## Phase 2: Internal Call and Preset Handling (Done)

1.  **Implement `load_presets`:**
    *   Correctly construct the preset path from `preset_name` and `runtime_dir`.
    *   Load the `transform` and `compare` commands from the preset directory into `transform_cmd` and `compare_cmd` variables.

2.  **Implement `stage_file` and `stage_all`:**
    *   `stage_file`: This function is mostly there. We need to ensure the transform command is executed correctly.
    *   `stage_all`: This function needs to be made more robust. It should handle both single files and directories as input and correctly iterate over the files to be staged.

3.  **Implement `handle_internal_call`:**
    *   This is the core of the internal mode.
    *   It should first create a staging directory for the left and right side of the diff.
    *   It should then call `stage_all` for both the left and right paths provided by `kubectl`/`argocd`.
    *   Finally, it should execute the `compare_cmd` with the two staging directories as arguments.

4.  **Refine `main` function for internal flow:**
    *   Update the `main` function to call `handle_internal_call` when `interactive` is false.

## Phase 3: Testing and Refinement (In Progress)

**Next Action:** Fix the failing `test/interactive-flow.sh` test. The user will manually fix the PID-related bug causing the failure.

1.  **Create test cases:**
    *   Add tests to the `test` directory to cover both interactive and internal modes.
    *   Use the existing fixtures and create new ones as needed.
    *   The `test-configmap-scope.sh` can be a good starting point.

2.  **Refine and debug:**
    *   Run the tests and debug any issues.
    *   Pay close attention to argument parsing, path handling, and command execution.
    *   Add `set -x` to the script for debugging purposes.

3.  **Documentation:**
    *   Review and update the `show_help` message and function docstrings to reflect the final implementation.
    *   Update `GEMINI.md` if necessary.
