# Plan

This document outlines the development plan for `kdiff`, a command-line tool to enhance the `kubectl diff` and `argocd diff` user experience.

## MVP Design

The Minimum Viable Product (MVP) will be a single, self-contained Bash script named `kdiff`. Its primary goal is to act as a smart wrapper that preprocesses Kubernetes manifests before they are passed to a standard diff utility.

### Core Philosophy

-   **Simplicity:** No complex dependencies beyond what's common in a Kubernetes operator's environment.
-   **Unix Philosophy:** Do one thing well. `kdiff` wraps and filters; it does not re-implement diffing.
-   **Stateless:** The MVP will not save state, configurations, or diff outputs.

### Dependencies

-   `bash` (v4+)
-   `yq` (v4, specifically the Go implementation by Mike Farah)
-   `diffutils` (for the `diff` command)
-   `mktemp`

### Invocation and Logic

`kdiff` will operate in two distinct modes, determined by its arguments.

1.  **User-Facing Mode (Wrapper):** This is the default mode when a user calls `kdiff`.
    -   **Action:** It parses its own arguments (e.g., `--scope`, `--kind`). It identifies the target command, which is everything after a `--` separator.
    -   **Execution:** It sets the `KUBECTL_EXTERNAL_DIFF` environment variable to call *itself* in the second mode, passing along the parsed filter arguments. It then executes the target command (e.g., `kubectl diff ...`).

2.  **Internal Mode (Processor):** This mode is triggered by a special, undocumented flag like `--internal-diff-processor`. It is only ever meant to be called by `kubectl` itself.
    -   **Action:** `kubectl` invokes this mode with two arguments: the file path to the "live" resource and the file path to the "local" resource.
    -   **Execution Steps:**
        1.  **(Kind Filtering):** It uses `yq '.kind'` on one of the files to get the resource kind. If the `--kind` filter was passed and this resource's kind does not match, it will echo a message like `INFO: Filtering out kind: Deployment` to `stderr` and **exit with code 0**. This tells `kubectl` that there is "no diff" for this resource, effectively hiding it.
        2.  **(Transformation):** If the resource is not filtered, it creates two temporary files using `mktemp`.
        3.  It applies the `yq` transformations specified by `--scope` or `--yq` to the original files, saving the results into the two temporary files.
        4.  **(Diffing):** It executes `diff -u` (or the user's original `KUBECTL_EXTERNAL_DIFF` if it was set) on the two *temporary* files, printing the result to `stdout`.
        5.  **(Cleanup):** It uses a `trap` to ensure the temporary files are always deleted on exit.

### MVP Command-Line Interface

```text
kdiff [FLAGS] -- <COMMAND>

FLAGS:
  --kind=<kind>,<kind>   Only show diffs for specified resource kinds (e.g., Pod,Service,po,svc).
                        Case-insensitive.
  --scope=<yq_path>     Shortcut to diff only a specific part of a resource (e.g., .spec).
  --yq=<yq_expression>  Apply an arbitrary yq expression to both manifests before diffing.
  --help                Show this help message.

INTERNAL FLAGS (not for direct use):
  --internal-diff-processor
```

### Example Walkthrough

**Command:** `kdiff --scope=.spec --kind=Deployment -- kubectl diff -f my-app/`

1.  `kdiff` (User Mode) is executed.
2.  It parses `--scope=.spec` and `--kind=Deployment`.
3.  It sets `export KUBECTL_EXTERNAL_DIFF="kdiff --internal-diff-processor --scope=.spec --kind=Deployment"`.
4.  It executes `kubectl diff -f my-app/`.
5.  `kubectl` finds a `Service` resource. It calls:
    `kdiff --internal-diff-processor ... /tmp/live-svc.yaml /tmp/local-svc.yaml`
6.  `kdiff` (Internal Mode) sees the kind is `Service`, which does not match `--kind=Deployment`. It prints nothing and exits 0.
7.  `kubectl` finds a `Deployment`. It calls:
    `kdiff --internal-diff-processor ... /tmp/live-deploy.yaml /tmp/local-deploy.yaml`
8.  `kdiff` (Internal Mode) sees the kind is `Deployment`, which matches.
9.  It creates `temp1.yaml` and `temp2.yaml`.
10. It runs `yq '.spec' /tmp/live-deploy.yaml > temp1.yaml` and `yq '.spec' /tmp/local-deploy.yaml > temp2.yaml`.
11. It runs `diff -u temp1.yaml temp2.yaml`, printing the output.
12. The `trap` cleans up the temp files.

---

## Next Steps

Once the MVP is stable and functional, the following improvements provide the most value.

1.  **Configuration File:**
    -   Implement support for a configuration file (e.g., `~/.kdiffrc`, `.kdiff.yaml`).
    -   This file should allow users to define default settings, especially a list of noisy fields to always ignore using a default `--yq` expression.
    -   Example: `ignore: [.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration", .status]`

2.  **Flexible Diff Tool Integration:**
    -   Allow the user to specify their preferred diff tool (`delta`, `difftastic`, `dyff`).
    -   Introduce a `--diff-tool <tool>` flag and/or a `KDIFF_TOOL` environment variable.
    -   Intelligently detect if the user's original `KUBECTL_EXTERNAL_DIFF` was already set to a fancy diff tool and use that for the final step.

3.  **Improved `argocd diff` Handling:**
    -   `argocd diff` does not use `KUBECTL_EXTERNAL_DIFF`. It prints a diff stream directly.
    -   Modify `kdiff` to detect if the wrapped command is `argocd diff`.
    -   If so, instead of setting `KUBECTL_EXTERNAL_DIFF`, it should run `argocd diff` and pipe its output to a *parser* function that can apply `--kind` filtering on the diff headers *after the fact*. This is a post-processing step, not a pre-processing one.

4.  **Packaging and Distribution:**
    -   Create a simple `Makefile` for `install` and `uninstall`.
    -   Create a Homebrew formula for easy installation on macOS.
    -   Publish the script to a Git repository with a clear `README.md`.

---

## Wild Ideas

This section is for long-term, inspirational goals that could be built upon a successful `kdiff` tool.

-   **Interactive Mode:** After generating the full diff, `kdiff` could enter an interactive mode: "Found 5 diffs. What do you want to see? `[a]ll, by [k]ind, by [n]ame, [q]uit`". This would turn it into a powerful review tool without needing file persistence.

-   **The Persistence Workflow (Revisited as a separate tool):** A second tool, say `kdiff-review`, could be created. It would take a diff stream from `kdiff` as input (`kdiff -- ... | kdiff-review --save ./diffs`) and handle all the logic of saving, updating, preserving comments, and managing review status. This keeps `kdiff` focused and adheres to the Unix philosophy.

-   **Git Integration:** Create a `git-kdiff` driver. When a user runs `git diff my-service.yaml`, Git could be configured to run `kdiff` to compare the staged version of `my-service.yaml` against the *live version in the cluster*, not just the `HEAD` version. This would provide an immediate "will this apply cleanly?" check right from Git.

-   **Diff Summarization:** Instead of a line-by-line diff, integrate with a tool like `dyff` to provide a human-readable summary: `Deployment 'my-app': image tag changed (1.2 -> 1.3), replicas changed (2 -> 3)`. This could be enabled with a `--summary` flag.

-   **Policy Engine Pre-flight:** Add a `--validate-with <policy_engine>` flag. Before diffing, `kdiff` could run the local manifest through a policy engine like OPA or Gatekeeper and annotate the diff with potential policy violations this change would introduce.
