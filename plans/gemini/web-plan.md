# kdiff Development Plan

This document outlines the design and development path for `kdiff`, a command-line tool to enhance the `kubectl diff` and `argocd diff` experience.

The plan prioritizes a minimal, yet functional, pure Bash MVP, followed by clear next steps for expansion.

---

## MVP Design

**Goal:** Create a single `kdiff` Bash script that can act as both an interactive wrapper and a `KUBECTL_EXTERNAL_DIFF` processor. The core logic relies on intercepting the manifests before they are diffed.

**Core Principle:** The script will have two distinct operational modes, distinguished by an internal flag (`--internal-exec-mode`). The script will call itself to switch between modes.

1.  **Interactive Wrapper Mode (Default):**
    * **Usage:** `kdiff [FILTER_OPTIONS] -- <COMMAND>`
    * **Example:** `kdiff --yq 'del(.status)' -- kubectl diff -f my-app/`
    * **Action:** The script parses the filter options (`--yq '...'`). It then exports the `KUBECTL_EXTERNAL_DIFF` variable, setting it to call *itself* with the parsed options and the internal flag. Finally, it executes the user's provided `<COMMAND>`.
    * `export KUBECTL_EXTERNAL_DIFF="kdiff --yq 'del(.status)' --internal-exec-mode"`
    * `exec kubectl diff -f my-app/`

2.  **External Diff Mode (Internal):**
    * **Usage:** This mode is triggered automatically by `kubectl` because of the exported variable.
    * **Example Call from `kubectl`:** `kdiff --yq 'del(.status)' --internal-exec-mode /tmp/manifest-A.yaml /tmp/manifest-B.yaml`
    * **Action:**
        * The script detects the `--internal-exec-mode` flag.
        * It takes the two file paths provided by `kubectl`.
        * It applies the filter from the `--yq` argument to both files using `yq`, creating two new temporary filtered files.
        * It executes a standard diff tool (e.g., `delta`, `diff`) on the two *filtered* temporary files. The tool can be chosen via a `KDIFF_TOOL` environment variable, defaulting to `diff`.
        * It cleans up the temporary filtered files upon exit.

### Actionable Outline

1.  **Setup:** Create the `kdiff` bash script file and make it executable.
2.  **Prerequisite Check:** Add a function to ensure `yq` and `diff` are installed and in the `PATH`.
3.  **Argument Parsing:**
    * Implement a `while` loop with `getopts` to parse flags (`--yq`, `--internal-exec-mode`, `--help`).
    * Write logic to separate `kdiff` options from the command to be executed (everything after a standalone `--`).
4.  **Mode Logic:**
    * Use an `if` statement to check for the presence of the `--internal-exec-mode` flag.
    * **If flag is present:** Implement the **External Diff Mode** logic (apply `yq`, run `diff`, cleanup).
    * **If flag is not present:** Implement the **Interactive Wrapper Mode** logic (export `KUBECTL_EXTERNAL_DIFF`, `exec` the user's command).
5.  **Help Message:** Add a simple `usage()` function that explains the basic syntax and is triggered by `--help` or incorrect arguments.

---

## Next Steps

Once the MVP is functional, these are the highest-impact improvements.

1.  **User-Friendly Filters:**
    * Implement flags like `--scope <jsonpath>`, `--kind <kind>`, and `--ignore-noisy` that the script translates into pre-canned `yq` expressions.
    * Example: `kdiff --ignore-noisy` would become `kdiff --yq 'del(.status, .metadata.managedFields)'`. This is the single biggest usability improvement.

2.  **Configuration File:**
    * Add support for a `~/.config/kdiff/config.yaml` file.
    * This would allow users to define a default `diff_tool`, create aliases for complex filter sets (`ignore_metadata: 'del(.metadata)'`), and set up "profiles" for common commands.
    * **Note:** This step would likely require evolving the tool into a hybrid Bash/Python solution or rewriting it in a language like Go or Rust to handle YAML parsing gracefully.

3.  **Enhanced Tool Integration:**
    * Improve the integration with different diff tools. Instead of just calling the command, `kdiff` could pass tool-specific flags for better output (e.g., `--language=yaml` for `delta`).
    * Formally test and document usage with `argocd diff`.

---

## Wild Ideas 🤩

Brainstorming for the long-term evolution of `kdiff`.

* **Interactive Filter Builder:** An interactive mode (`kdiff --build-filter my-manifest.yaml`) that opens the manifest in a TUI (Text-based User Interface). You could navigate the YAML tree and press a key to select/deselect fields, with `kdiff` automatically generating the correct `--yq` filter string for you.
* **Diff Summarization (`--summarize`):** For changes affecting many resources identically (e.g., adding an annotation), instead of showing 50 identical diffs, it could provide a summary: "SUMMARY: 50 resources changed: `metadata.annotations` added `my-annotation: true`". This would require `kdiff` to parse and compare the manifests intelligently before diffing.
* **Diff as Infrastructure Tests:** Introduce an "assert" mode. You would save a "golden" diff output and then run `kdiff --assert-equals golden.diff -- kustomize build . | kubectl diff -f -`. The tool would exit with a non-zero status if the live diff doesn't match the golden one, turning infrastructure changes into testable artifacts for CI/CD.
* **"What's This?" Integration:** After displaying a diff, allow the user to ask for an explanation of a changed field. If `spec.strategy.type` changed, a sub-command could pipe this path directly to `kubectl explain deployment.spec.strategy.type`, linking the *what* of the change to the *why*.
