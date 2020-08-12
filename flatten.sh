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

    local script="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to flatten() at line $(caller)"
    fi

    continuation=

    exec <"$script"
    while IFS= read -r input; do
        if
            path=$(say "$input" | awk '$1=="use-from" {print $2}')
            [ -n "$path" -a -z "$continuation" ]
        then
            __posh__flatten__path=$(__posh__prependpath "$__posh__flatten__path" "$path")
            say "# USE FROM $path >> $__posh__flatten__path"
        elif
            module=$(say "$input" | awk '$1=="use" {print $2}')
            [ -n "$module" -a -z "$continuation" ]
        then
            say "# BEGIN USE $module"
            __posh__descend flatten "$module"
            say "# END USE $module"
        elif [ "${input#.}" != "$input" -o "${input#source}" != "$input" ] &&
                [ "${input%poshlib.sh *}" != "${input}" ]; then
            # Simulate a fresh usepath and stacktrace while flattening.
            # WARNING: this may end up using a different version of poshlib.
            # Also, this only works if nobody has done anything nonstandard to
            # __posh__usepath since we initialised it.
            __posh__flatten__path="${__posh__usepath##*:}"
            __posh__flatten__trace="${script}"
            say "# FLATTEN: init usepath=$__posh__flatten__path"
            say "# FLATTEN: init stacktrace=$__posh__flatten__trace"
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
