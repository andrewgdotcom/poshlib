# shellcheck disable=SC2148
################################################################################
# Flatten a poshlib script with use dependencies into a static script.
# Any libs/source files to be flattened MUST be sourced using `use` and not
# `source` or `.`, and the `use` command must appear on a line by itself.
# Flattened dependencies will be recursively processed.
#
# This tool produces the flattened output on STDOUT.
################################################################################

flatten() { (
    use strict
    use utils

    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: COMMAND: flatten $*"

    local script="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to flatten() at line $(caller)"
    fi

    local words=()
    local verb rest input path module continuation

    exec <"$script"
    while IFS= read -r input; do
        if
            IFS=$' \t' read -ra words <<<"$input"
            [ "${words[0]:-}" = "use-from" ] && [ -z "$continuation" ]
        then
            path="${words[1]}"
            [ -n "$path" ] || die 101 "Syntax error: 'use-from' requires an argument"
            __posh__flatten__path=$(__posh__prependpath "$__posh__flatten__path" "$path" "$__posh__flatten__stack")
            say "# FLATTEN: USE FROM $path >> $__posh__flatten__path"
        elif
            IFS=$' \t' read -ra words <<<"$input"
            [ "${words[0]:-}" = "use" ] && [ -z "$continuation" ]
        then
            module="${words[1]}"
            [ -n "$module" ] || die 101 "Syntax error: 'use' requires an argument"
            say "# FLATTEN: USE $module"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: USE $module"
            __posh__descend flatten "$module"
            say "# FLATTEN: END USE $module"
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: FLATTEN: END USE $module"
        elif
            {
                IFS=$' \t' read -r verb rest <<<"$input"
                { [ "${verb:-}" = "." ] || [ "${verb:-}" = "source" ] ; } && \
                    [ -n "${rest:-}" ] && [ "${rest%/poshlib.sh*}" != "${rest}" ]
            }
        then
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
