################################################################################
# Flatten a poshlib script with use dependencies into a static script.
# Any libs/source files to be flattened MUST be sourced using `use` and not
# `source` or `.`, and the `use` command must appear on a line by itself.
# Flattened dependencies will be recursively processed.
#
# This tool produces the flattened output on STDOUT.
################################################################################

flatten() { (
    use swine

    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: COMMAND: flatten $*"

    local script="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to flatten() at line $(caller)"
    fi

    continuation=

    exec <"$script"
    while IFS= read -r input; do
        if
            path=$(say "$input" | awk '$1=="use-from" {print $2}')
            [ -n "$path" ] && [ -z "$continuation" ]
        then
            __posh__flatten__path=$(__posh__prependpath "$__posh__flatten__path" "$path" "$__posh__flatten__stack")
            say "# FLATTEN: USE FROM $path >> $__posh__flatten__path"
        elif
            module=$(say "$input" | awk '$1=="use" {print $2}')
            [ -n "$module" ] && [ -z "$continuation" ]
        then
            say "# FLATTEN: USE $module"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: USE $module"
            __posh__descend flatten "$module"
            say "# FLATTEN: END USE $module"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: END USE $module"
        elif ! awk \
"/^[ \t]*(\.[ \t]|source[ \t]).*\/poshlib.sh([ \t|&\"\')].*)?$/ {exit 1}" \
                <<< "${input}"; then
            # Note: awk will exit 0 by default so we "fail" on match and
            # invert the test above.

            # Simulate a fresh usepath and callstack while flattening.
            # WARNING: this may end up using a different version of poshlib.
            # Also, this only works if nobody has done anything nonstandard to
            # __posh__usepath since we initialised it.
            # shellcheck disable=SC2154
            __posh__flatten__path="${__posh__usepath##*:}"
            __posh__flatten__stack="${script}"
            say "# FLATTEN: INIT usepath=$__posh__flatten__path"
            say "# FLATTEN: INIT callstack=$__posh__flatten__stack"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: INIT flatten_path=$__posh__flatten__path"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: INIT flatten_stack=$__posh__flatten__stack"
        else
            say "$input"
        fi
        if [ "${input%\\}" != "${input}" ]; then
            continuation=1
        else
            continuation=
        fi
    done
) }
