# shellcheck disable=SC2148
################################################################################
# Shell functions for CRUD manipulation of key/value pairs in shell-like files
# e.g. `FOO=bar`
#
# Four functions are defined, one each for CRUD.
# One further function is defined as an `eval` wrapper.
#
# The first argument to each function is the name of the file
# The optional second argument is the key to be read or written
# The optional third argument is the value to be written.
#
# If `keyval.read` is passed no key, then it reads all key-value pairs.
#
# `keyval.import` calls `keyval.read` and uses the key-value pairs returned to
# update the corresponding variables in the calling context.
#
# `keyval.import` is safer than `source` as only `key=value` lines are processed.
################################################################################

__keyval.sedescape() {
    # Escape any characters likely to confuse sed
    sed -E -e 's/([][\\&./])/\\\1/g' <<< "$1"
}

keyval.read() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="STRIP"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="${1:-}"

    if [ -n "$key" ]; then
        regex="^\\s*${key}(\[[A-Za-z0-9_]+\])?="
    else
        regex="^\\s*[][A-Za-z0-9_]+="
    fi
    ( grep -E "$regex" "$filename" || true ) | while IFS=$'\n' read -r line; do
        [ -n "$line" ] || continue
        key="${line%%=*}"
        val="${line#*=}"
        if [ "${STRIP:-}" != "false" ]; then
            # Strip enclosing quotes
            val=$(sed -E -e 's/^"(.*)"$/\1/' <<< "$val")
            val=$(sed -E -e "s/^'(.*)'$/\1/" <<< "$val")
        fi
        printf "%s=%q\n" "${key}" "${val}"
    done
)}
keyval-read () { keyval.read "$@" ;}

keyval.import() {
    eval "$(keyval.read "$@")"
}

keyval.add() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="UPDATE MULTI MATCH_INDENT"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    keyquote=$(__keyval.sedescape "$key")
    valquote=$(__keyval.sedescape "$val")

    if ! grep -Eq "^\\s*${keyquote}=" "$filename" 2>/dev/null || [ "${MULTI:-}" == true ]; then
        # Either there is no matching uncommented key, or we don't care
        if grep -Eq "^\\s*#?\\s*${keyquote}=${valquote}\$" "$filename" 2>/dev/null; then
            # If an exact match exists (commented or otherwise), forcibly uncomment it
            if [ "${MATCH_INDENT:-}" == true ]; then
                sed -i -e "s/^\\(\\s*\\)#\\(\\s*${keyquote}=${valquote}\\)$/\\1\\2/" "$filename"
            else
                sed -i -e "s/^\\s*#\\s*\\(${keyquote}=${valquote}\\)$/\\1/" "$filename"
            fi
        elif grep -Eq "^\\s*#?\\s*${keyquote}=" "$filename" 2>/dev/null; then
            # Add above the first existing line (commented or otherwise)
            # https://stackoverflow.com/a/33416489
            # This matches the first instance, replaces using a repeat regex, then
            # enters an inner loop that consumes the rest of the file verbatim
            if [ "${MATCH_INDENT:-}" == true ]; then
                sed -i -e "/^\\(\\s*\\)\\(#\?\\)\\(\\s*${keyquote}=\\)/ {
                    s//\\1\\3${valquote}\\n\\1\\2\\3/
                    :a
                    \$! {
                        n
                        ba
                    } \
                }" "$filename"
            else
                sed -i -e "/^\\(\\s*#\?\\s*\\)\\(${keyquote}=\\)/ {
                    s//\\2${valquote}\\n\\1\\2/
                    :a
                    \$! {
                        n
                        ba
                    }
                }" "$filename"
            fi
        else
            say "${key}=${val}" >> "$filename"
        fi
    elif [ "${UPDATE:-}" != "false" ]; then
        # There is a matching uncommented key AND the value must be modified
        keyval.update --no-add "$filename" "$key" "$val"
    fi
)}
keyval-add () { keyval.add "$@" ;}

keyval.update() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="ADD MATCH_INDENT"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    keyquote=$(__keyval.sedescape "$key")
    valquote=$(__keyval.sedescape "$val")

    sed -i -e "s/^\\(\\s*${keyquote}=\\).*$/\\1${valquote}/" "$filename"
    if [ "${ADD:-}" != "false" ] && ! grep -E -q "^\\s*${keyquote}=" "$filename"; then
        MATCH_INDENT="${MATCH_INDENT:-}" keyval-add --no-update "$filename" "$key" "$val"
    fi
)}
keyval-update () { keyval.update "$@" ;}

keyval.delete() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="COMMENT"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    keyquote=$(__keyval.sedescape "$1")

    if [ "${COMMENT:-}" == "true" ]; then
        # comment out instead of deleting
        sed -E -i -e "s/^\\s*${keyquote}(\[[A-Za-z0-9_]+\])?=/#&/" "$filename"
    else
        sed -E -i -e "/^\\s*${keyquote}(\[[A-Za-z0-9_]+\])?=.*$/d" "$filename"
    fi
)}
keyval-delete () { keyval.delete "$@" ;}
