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

keyval-read() {(
    use swine
    use parse-opt

    filename="$1"; shift
    key="${1:-}"

    if [ -n "$key" ]; then
        egrep "^\s*${key}=" "$filename" || true
    else
        egrep "^\s*[][A-Za-z0-9_]=" "$filename" || true
    fi
)}

keyval-add() {(
    use swine
    use parse-opt

    PO_SIMPLE_FLAGS="QUOTE UPDATE"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    # process $val for regex-escapes, quotes

    if ! egrep -q "^\s*${key}=" "$filename"; then
        say "${key}=${val}" >> "$filename"
    elif [ "${UPDATE:-}" != "false" ]; then
        # Don't use sed -E because that interprets [] and these may appear on LHS
        sed -i -e "s/^\(\s*${key}=\).*$/\1${val}/" "$filename"
    fi
)}

keyval-update() {(
    use swine
    use parse-opt

    PO_SIMPLE_FLAGS="QUOTE ADD"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"; shift
    val="${1:-}"

    # process $val for regex-escapes, quotes

    # Don't use sed -E because that interprets [] and these may appear on LHS
    sed -i -e "s/^\(\s*${key}=\).*$/\1${val}/" "$filename"
    if [ "${ADD:-}" != "false" ] && ! egrep -q "^\s*${key}=" "$filename"; then
        say "${key}=${val}" >> "$filename"
    fi
)}

keyval-delete() {(
    use swine
    use parse-opt

    PO_SIMPLE_FLAGS="COMMENT"
    eval "$(parse-opt-simple)"

    filename="$1"; shift
    key="$1"

    if [ "${COMMENT:-}" == "true" ]; then
        # comment out instead of deleting
        sed -i -e "s/^\s*${key}=/#&/" "$filename"
    else
        sed -i -e "/^\s*${key}=.*$/d" "$filename"
    fi
)}
