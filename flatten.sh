################################################################################
# Flatten a poshlib script with use dependencies into a static script.
# This is particularly useful with e.g. `ansible -m script`, where the script
# depends on other scripts/libs that would not otherwise be copied by ansible.
#
# Any libs/source files to be flattened MUST be sourced using `use` and not
# `source` or `.`, and the `use` command must appear on a line by itself.
# Flattened dependencies will be recursively processed.
#
# BEWARE that flattening will be performed using the running shell's USEPATH,
# and NOT the USEPATH that may be overridden in the target script's runtime.
#
# This tool produces the flattened output on STDOUT.
################################################################################

flatten() { (
    use swine

    local script="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to flatten() at line $(caller)"
    fi

    recurse() {
        local dir
        local IFS=:
        for dir in $USEPATH; do
            if [ -f "$dir/$1.sh" ]; then
                flatten "$dir/$1.sh"
                return 0
            fi
        done
        die 101 "Could not find $1.sh in $USEPATH"
    }

    continuation=

    exec <"$script"
    while IFS= read -r input; do
        if
            module=$(say "$input" | awk '$1=="use" {print $2}')
            [ -n "$module" -a -z "$continuation" ]
        then
            say "# BEGIN FLATTEN USE $module"
            recurse "$module"
            say "# END FLATTEN USE $module"
        elif [ "${input#.}" != "$input" -o "${input#source}" != "$input" ] &&
                [ "${input%poshlib.sh}" != "${input}" ]; then
            say "# FLATTENED POSHLIB"
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
