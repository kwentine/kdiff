# TODO

This file tracks the development tasks for the kdiff project.

## High Priority

### Core Implementation
- [x] **Implement basic kdiff script structure with argument parsing**
  - Create main kdiff script file
  - Add command-line argument parsing for --kind, --scope, --yq flags
  - Implement --help functionality
  - Handle the `--` separator to identify target command

- [ ] **Add user-facing mode (wrapper) functionality**
  - Parse user arguments and store filter options
  - Set KUBECTL_EXTERNAL_DIFF environment variable to call self in internal mode
  - Execute the target command (kubectl diff, argocd diff, etc.)
  - Preserve user's original KUBECTL_EXTERNAL_DIFF if set

- [ ] **Add internal comparison mode for kubectl integration**
  - Implement --internal-diff-processor flag handling
  - Accept two file paths from kubectl (live and local resources)
  - Process the files according to filter options
  - Call appropriate diff tool on processed files

## Medium Priority

### Filtering and Processing
- [ ] **Implement yq transformation and filtering logic**
  - Kind filtering: check resource .kind against --kind filter
  - Scope filtering: apply --scope yq expression
  - Custom yq expressions via --yq flag
  - Create and manage temporary files for processed manifests

- [ ] **Add proper error handling and cleanup**
  - Implement trap for temporary file cleanup
  - Handle missing dependencies (yq, diff)
  - Validate yq expressions and file paths
  - Provide meaningful error messages

## Low Priority

### Testing and Documentation
- [ ] **Create test cases and validation**
  - Unit tests for argument parsing
  - Integration tests with sample Kubernetes manifests
  - Test different resource kinds and yq expressions
  - Validate KUBECTL_EXTERNAL_DIFF integration

## Future Enhancements
- [ ] Configuration file support (~/.kdiffrc)
- [ ] Flexible diff tool integration (delta, difftastic, dyff)
- [ ] Packaging and distribution (Makefile, Homebrew formula)

## Notes
- Dependencies: bash (v4+), yq (v4 Go implementation), diffutils, mktemp
- Target: Single self-contained bash script
- Follow Unix philosophy: do one thing well