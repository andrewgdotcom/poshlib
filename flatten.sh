################################################################################
# Flatten a poshlib script with use dependencies into a static script.
# This is particularly useful with e.g. `ansible -m script`, where the script
# depends on other scripts/libs that would not otherwise be copied by ansible.
#
# Any libs/source files to be flattened MUST be sourced using `use` and not
# `source` or `.`, and the `use` command must appear on a line by itself.
# Flattened dependencies will be recursively processed.
#
# This tool produces a temporary output file and prints its name on STDOUT.
# It should be invoked as e.g.:
#
#   ansible -m script -a $(flatten ./do-things.sh)
################################################################################

flatten() { (
    use swine

    recurse() {
        local dir
        local IFS=:
        for dir in $USEPATH; do
            if [[ -f "$dir/$1.sh" ]]; then
                flatten "$dir/$1.sh"
                return 0
            fi
        done
        echo "Could not find $1.sh in $USEPATH" 2>&1
        exit 101
    }

    outfile=$(mktemp) || die 1001 "Could not open temporary file"
    continuation=

    exec <"$1"
    while IFS= read -r input; do
        if module=$(awk '$1=="use" {print $2}' <<<"$input"); [[ $module && ! $continuation ]]; then
            echo "# BEGIN FLATTEN USE $module" >> $outfile
            cat $(recurse "$module") >> $outfile
            echo "# END FLATTEN USE $module" >> $outfile
        else
            echo "$input" >> $outfile
        fi
        if [[ "${input%\\}" != "${input}" ]]; then
            continuation=1
        else
            continuation=
        fi
    done

    echo "$outfile"
) }
