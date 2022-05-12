# shellcheck disable=SC2148
################################################################################
# Shell functions for CRUD manipulation of key/value pairs in shell files
# e.g. `FOO=bar`
#
# Four functions are defined, one each for CRUD.
# The first argument to each function is the name of the file
# The optional second argument is the key to be read or written
# The optional third argument is the value to be written.
#
# Note that the output of keyval-read() must be eval-ed for its `key=value`
# pairs to be usable in the calling routine. If keyval-read is passed no key,
# then it reads (and outputs) all key-value pairs.
# `eval $(keyval-read FILE)` is preferable to sourcing when only `key=value`
# variable settings are desired.
################################################################################

_sedescape() {
    # Escape any characters likely to confuse sed
    sed -E -e 's/([][\\&./])/\\\1/g' <<< "$1"
}

keyval-read() {(
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

keyval-add() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="UPDATE MULTI"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    keyquote=$(_sedescape "$key")
    valquote=$(_sedescape "$val")

    if ! grep -Eq "^\\s*${keyquote}=" "$filename" 2>/dev/null || [ "${MULTI:-}" == true ]; then
        # Either there is no matching uncommented key, or we don't care
        if grep -Eq "^\\s*#?\\s*${keyquote}=${valquote}\$" "$filename" 2>/dev/null; then
            # If an exact match exists (commented or otherwise), forcibly uncomment it
            sed -i -e "s/^\\(\\s*\\)#\\(\\s*${keyquote}=${valquote}\\)$/\\1\\2/" "$filename"
        elif grep -Eq "^\\s*#?\\s*${keyquote}=" "$filename" 2>/dev/null; then
            # Add above the first existing line (commented or otherwise)
            # https://stackoverflow.com/a/33416489
            # This matches the first instance, replaces using a repeat regex, then
            # enters an inner loop that consumes the rest of the file verbatim
            sed -i -e "/^\\(\\s*\\)\\(#\?\\)\\(\\s*${keyquote}=\\)/ {s//\\1\\3${valquote}\\n\\1\\2\\3/; " -e ':a' -e '$!{n;ba' -e '};}' "$filename"
        else
            say "${key}=${val}" >> "$filename"
        fi
    elif [ "${UPDATE:-}" != "false" ]; then
        # There is a matching uncommented key AND the value must be modified
        keyval-update --no-add "$filename" "$key" "$val"
    fi
)}

keyval-update() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="ADD"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    keyquote=$(_sedescape "$key")
    valquote=$(_sedescape "$val")

    sed -i -e "s/^\\(\\s*${keyquote}=\\).*$/\\1${valquote}/" "$filename"
    if [ "${ADD:-}" != "false" ] && ! grep -E -q "^\\s*${keyquote}=" "$filename"; then
        keyval-add --no-update "$filename" "$key" "$val"
    fi
)}

keyval-delete() {(
    use swine
    use parse-opt

    # shellcheck disable=SC2034
    PO_SIMPLE_FLAGS="COMMENT"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    keyquote=$(_sedescape "$1")

    if [ "${COMMENT:-}" == "true" ]; then
        # comment out instead of deleting
        sed -E -i -e "s/^\\s*${keyquote}(\[[A-Za-z0-9_]+\])?=/#&/" "$filename"
    else
        sed -E -i -e "/^\\s*${keyquote}(\[[A-Za-z0-9_]+\])?=.*$/d" "$filename"
    fi
)}
