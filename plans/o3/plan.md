# kdiff PLAN

## Minimal Design (MVP)

**Scope:** Provide a filtered diff by preprocessing *one* old and *one* new manifest file (the pair passed by `kubectl` as external diff). Support exactly four user-facing preprocessing flags: `--kind`, `--scope`, `--ignore`, `--yq`.

### Supported Flags (MVP)

| Flag       | Value Form                                             | Action                                                      | Notes                                                                                |
| ---------- | ------------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `--kind`   | Single kind name (case-insensitive), e.g. `Deployment` | If the manifest `.kind` != value → emit nothing (exit 0).   | No list/regex in MVP; extend later.                                                  |
| `--scope`  | Single dot path (e.g. `.spec`)                         | Replace the document with only that subtree.                | If path missing → treat as empty object `{}` so diff clearly shows removal/addition. |
| `--ignore` | Single dot path (e.g. `.metadata.annotations`)         | Delete that path before scoping.                            | If path absent → no-op. Applied before `--scope`.                                    |
| `--yq`     | Arbitrary yq expression string                         | Apply expression after ignore & scope to transform the doc. | Expression runs on the *scoped* document. If yq not installed → error.               |

### Processing Order

1. Parse old file → `old_doc`; parse new file → `new_doc` (single YAML each).
2. If `--kind` set and (`old_doc.kind` != kind and `new_doc.kind` != kind) → exit 0 (nothing to show).
3. Apply `--ignore` to each present doc (delete path).
4. Apply `--scope` (if set) to each: replace doc with subtree at path (or `{}` if missing).
5. Apply `--yq` expression (if provided) to each resulting doc.
6. Serialize both docs with stable formatting (alphabetic key order, 2-space indent).
7. Write normalized temp files.
8. Determine downstream diff tool:
   - If `KDIFF_SAVED_EXTERNAL_DIFF` is set and not empty and not `kdiff` → run: `$KDIFF_SAVED_EXTERNAL_DIFF <old_norm> <new_norm>`.
   - Else run: `diff -u -N <old_norm> <new_norm>`.
9. Exit code: 0 if no differences, 1 if differences, 2 on error (configurable later).

### Behavior Details

- **Empty Result:** If one side becomes empty due to scope (path missing) but the other has content → diff shows full addition/removal of that subtree.
- **Both Empty After Scope:** Emit no diff (exit 0).
- **Kind Filtering Edge:** If old kind matches but new doesn’t (or vice versa) still proceed (rename scenarios). MVP: only suppress when *both* differ.
- **Robustness:** If any transformation step fails (invalid yq syntax) → print error to stderr and exit 2.

### Minimal Implementation Pseudocode (External Mode)

```sh
kdiff --as-external-diff [flags] old.yml new.yml
  parse_yaml old.yml -> O
  parse_yaml new.yml -> N
  if --kind && ( (O && O.kind!=K) && (N && N.kind!=K) ); then exit 0; fi
  O' = apply_ignore(O); N' = apply_ignore(N)
  O'' = apply_scope(O'); N'' = apply_scope(N')
  O3 = apply_yq(O''); N3 = apply_yq(N'')
  write_temp O3 -> o.tmp; write_temp N3 -> n.tmp
  tool=${KDIFF_SAVED_EXTERNAL_DIFF:-}
  if [ -n "$tool" ] && [[ $tool != kdiff* ]]; then exec $tool o.tmp n.tmp; else diff -u -N o.tmp n.tmp; fi
  exit (diff exit code mapping)
```

## Ideas (Beyond MVP)

These are **not** in the Minimal Design but can guide future iterations:

| Idea                                    | Description                                                                    | Notes                                                  |                        |
| --------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------ | ---------------------- |
| Multiple `--kind` values / glob / regex | Allow `--kind=Deployment,Service` or \`--kind-regex='^(Deployment              | StatefulSet)\$'\`.                                     | Increases flexibility. |
| Multiple ignore paths                   | Accept comma-separated list.                                                   | Implement as loop.                                     |                        |
| Multiple scope paths (union)            | Merge multiple subtrees into a synthetic document.                             | Useful for comparing just `.spec` & selected metadata. |                        |
| Ignore presets                          | `--ignore-preset=ephemeral` deleting timestamps, managedFields, status.        | Fast noise reduction.                                  |                        |
| Built-in yq-less transforms             | Native Python path deletion to remove yq dependency for simple ignores/scopes. | Improves portability.                                  |                        |
| Fallback to `jq` for JSON manifests     | If manifests provided in JSON.                                                 | Optional.                                              |                        |
| Config file                             | Default flags in `~/.config/kdiff/config.yaml`.                                | Convenience.                                           |                        |
| Exit code customization                 | `--diff-exit-code=N`.                                                          | CI integration.                                        |                        |
| List sorting flags                      | Normalize order-insensitive lists.                                             | Reduces noise on selectors/env vars.                   |                        |
| Helm/Kustomize generator helpers        | Pre-build manifests both sides (old/new).                                      | Extends beyond kubectl external diff.                  |                        |
| Multi-doc support                       | Handle multi-doc YAML gracefully.                                              | Future compatibility.                                  |                        |
| Structured output mode                  | Emit processed pair (for piping into review tool).                             | Enables `kdiff_review`.                                |                        |
| Performance parallelism                 | Parallel parse + transform for larger docs.                                    | Likely overkill for single-resource external diff.     |                        |

## MVP Acceptance Criteria

- Running `kdiff --kind=Deployment --scope=.spec --ignore=.metadata.annotations -- kubectl diff -f deploy.yaml` executes without modifying parent shell env permanently and produces expected filtered diff.
- Error message clarity for invalid yq.
- Empty diff when kind filter excludes both sides.
- Correct exit codes (0 no diff / 1 diff / 2 error).

## Next Step

Implement external mode re-entry handling these four flags only, then add tests for: kind mismatch, ignore existing/missing path, scope missing path, yq transformation success/failure.
