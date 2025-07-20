#!/bin/bash
# kdiff - kubectl/argocd diff with transformations
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
VERSION="0.3.0"

# Default values
DEFAULT_DIFF_CMD="${KUBECTL_EXTERNAL_DIFF:-diff -u -N}"
KDIFF_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/kdiff"

# Help message
show_help() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - kubectl/argocd diff with yq transformations

USAGE:
    ${SCRIPT_NAME} [OPTIONS] -- <COMMAND>

OPTIONS:
    --yq <EXPR>          yq expression to apply before diffing
    --compare <CMD>      Command to compare the transformed files
                         Defaults to \$KUBECTL_EXTERNAL_DIFF or 'diff -u -N'
    --help               Show this help message

EXAMPLES:
    # Filter to deployment specs only
    ${SCRIPT_NAME} --yq '.spec' -- kubectl diff -f deployment.yaml

    # Remove noisy fields
    ${SCRIPT_NAME} --yq 'del(.metadata.managedFields, .status)' -- kubectl diff -f .

    # Use with custom compare command
    ${SCRIPT_NAME} --yq '.spec' --compare 'dyff between' -- kubectl diff -f deploy.yaml

PRESET MODE:
    When called as KUBECTL_EXTERNAL_DIFF, kdiff expects --preset <dir>
    pointing to a directory containing 'transform' and 'compare' executables.
    This is handled automatically when using kdiff interactively.

EOF
}

# Stage a single file with transformation
stage_file() {
    local src_file="$1"
    local dest_dir="$2"
    local transform_cmd="$3"
    
    local basename=$(basename "$src_file")
    local dest_file="$dest_dir/$basename"
    
    if [[ -n "$transform_cmd" ]] && [[ -x "$transform_cmd" ]]; then
        if ! "$transform_cmd" < "$src_file" > "$dest_file"; then
            echo "Warning: Transform failed for $src_file, copying original" >&2
            cp "$src_file" "$dest_file"
        fi
    else
        cp "$src_file" "$dest_file"
    fi
}

# Transform a file or directory to staging area
transform_to_staging() {
    local src_path="$1"
    local dest_dir="$2"
    local transform_cmd="$3"
    
    mkdir -p "$dest_dir"
    
    if [[ -f "$src_path" ]]; then
        # Single file
        stage_file "$src_path" "$dest_dir" "$transform_cmd"
    elif [[ -d "$src_path" ]]; then
        # Directory: process each file
        local file
        for file in "$src_path"/*; do
            [[ -f "$file" ]] && stage_file "$file" "$dest_dir" "$transform_cmd"
        done
    else
        echo "Error: Path is neither file nor directory: $src_path" >&2
        return 1
    fi
}

# Load preset configuration
load_preset() {
    local preset_dir="$1"
    
    if [[ ! -d "$preset_dir" ]]; then
        echo "Error: Preset directory not found: $preset_dir" >&2
        exit 1
    fi
    
    PRESET_TRANSFORM_CMD=""
    PRESET_COMPARE_CMD=""
    
    [[ -x "$preset_dir/transform" ]] && PRESET_TRANSFORM_CMD="$preset_dir/transform"
    [[ -x "$preset_dir/compare" ]] && PRESET_COMPARE_CMD="$preset_dir/compare"
}

# Handle external diff mode (called by kubectl/argocd)
handle_external_diff() {
    local from_path="$1"
    local to_path="$2"
    local preset_dir="$3"
    
    # Load configuration
    load_preset "$preset_dir"
    
    # Create staging area
    local staging_dir
    staging_dir=$(mktemp -d -t kdiff-staging.XXXXXX)
    trap 'rm -rf "$staging_dir"' EXIT INT TERM
    
    # Transform to staging
    transform_to_staging "$from_path" "$staging_dir/from" "$PRESET_TRANSFORM_CMD"
    transform_to_staging "$to_path" "$staging_dir/to" "$PRESET_TRANSFORM_CMD"
    
    # Compare
    local compare_cmd="${PRESET_COMPARE_CMD:-$DEFAULT_DIFF_CMD}"
    "$compare_cmd" "$staging_dir/from" "$staging_dir/to"
}

# Create temporary preset directory
create_temp_preset() {
    local yq_expr="$1"
    local compare_cmd="$2"
    local pid="$$"
    
    # Create preset directory
    mkdir -p "$KDIFF_RUNTIME_DIR"
    local preset_dir="$KDIFF_RUNTIME_DIR/preset-$pid"
    mkdir -p "$preset_dir"
    
    # Create transform script
    if [[ -n "$yq_expr" ]]; then
        cat > "$preset_dir/transform" << 'EOF'
#!/bin/bash
set -euo pipefail
EOF
        # Safely append the yq command with proper quoting
        printf 'yq eval %q -\n' "$yq_expr" >> "$preset_dir/transform"
    else
        # Default: no transformation
        cat > "$preset_dir/transform" << 'EOF'
#!/bin/bash
cat
EOF
    fi
    chmod +x "$preset_dir/transform"
    
    # Create compare script
    cat > "$preset_dir/compare" << 'EOF'
#!/bin/bash
set -euo pipefail
EOF
    if [[ -n "$compare_cmd" ]]; then
        echo "$compare_cmd \"\$@\"" >> "$preset_dir/compare"
    else
        echo "${KUBECTL_EXTERNAL_DIFF:-$DEFAULT_DIFF_CMD} \"\$@\"" >> "$preset_dir/compare"
    fi
    chmod +x "$preset_dir/compare"
    
    echo "$preset_dir"
}

# Main
main() {
    # Check for GNU getopt
    if ! command -v getopt >/dev/null; then
        echo "Error: GNU getopt is required but not found" >&2
        exit 1
    fi
    
    # Parse options with GNU getopt
    local opts
    if ! opts=$(getopt -o h -l yq:,compare:,preset:,help -n "$SCRIPT_NAME" -- "$@"); then
        show_help >&2
        exit 1
    fi
    
    eval set -- "$opts"
    
    local yq_expr=""
    local compare_cmd=""
    local preset_dir=""
    
    while true; do
        case "$1" in
            --yq)
                yq_expr="$2"
                shift 2
                ;;
            --compare)
                compare_cmd="$2"
                shift 2
                ;;
            --preset)
                preset_dir="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Error: Invalid option $1" >&2
                exit 1
                ;;
        esac
    done
    
    # Remaining arguments
    local remaining_args=("$@")
    
    # Detect mode: external diff if we have exactly 2 arguments that exist
    if [[ ${#remaining_args[@]} -eq 2 ]]; then
        local arg1="${remaining_args[0]}"
        local arg2="${remaining_args[1]}"
        
        if { [[ -f "$arg1" ]] || [[ -d "$arg1" ]]; } && 
           { [[ -f "$arg2" ]] || [[ -d "$arg2" ]]; }; then
            # External diff mode
            if [[ -z "$preset_dir" ]]; then
                echo "Error: kdiff called as external diff without --preset" >&2
                exit 1
            fi
            handle_external_diff "$arg1" "$arg2" "$preset_dir"
            exit $?
        fi
    fi
    
    # Interactive mode
    if [[ ${#remaining_args[@]} -eq 0 ]]; then
        echo "Error: No command specified" >&2
        show_help >&2
        exit 1
    fi
    
    if [[ -n "$preset_dir" ]]; then
        echo "Error: --preset is only for external diff mode" >&2
        exit 1
    fi
    
    # Create temporary preset
    local temp_preset
    temp_preset=$(create_temp_preset "$yq_expr" "$compare_cmd")
    trap 'rm -rf "$temp_preset"' EXIT INT TERM
    
    # Set as KUBECTL_EXTERNAL_DIFF
    export KUBECTL_EXTERNAL_DIFF="$0 --preset $temp_preset"
    
    # Execute command
    exec "${remaining_args[@]}"
}

# Run
main "$@"