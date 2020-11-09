########################################################################
#
# Low-level ASON tools. No user-serviceable components inside.
#
# In the following, we define:
#
# an "entity" is an ASON control character or escape sequence with special
# meaning in the plaintext layer.
# an "element" is an ASON plaintext string, which may include entities.
# a "structure" is a properly-nested ASON document beginning with the ASON
# magic number.
# an "item" is either an element or a structure.
# a "subscript" is a nonzero integer. A negative integer counts backwards
# from the last item.
# a "key" is an element.
# a "slice_def" is a colon-separated pair of (optional) subscripts. A
# missing first (second) subscript implies "1" ("-1").
# an "unbounded" slice_def has both subscripts missing
# a "bounded" slice_def has both subscripts present
# a "filter" is a comma-separated list of subscripts and slice_defs,
# or of keys.
#
########################################################################

use ason/entities

# Tests

__ason__is_plaintext_entity() {
    case "$1" in
    "$_UNDEF" | "$_TRUE" | "$_FALSE" | "$_PAD" | "$_PARA" )
        return 0
        ;;
    esac
    return 1
}

__ason__is_type_entity() {
    case "$1" in
    "$_QUOTE" | "$_LIST" | "$_DICT" | "$_TABLE" | "$_ARRAY" )
        return 0
        ;;
    esac
    return 1
}

__ason__is_entity() {
    __ason__is_plaintext_entity "$1" || __ason__is_type_entity "$1"
}

__ason__is_element() {
    header="${1%%${__AS__STX}*}"
    [ "$header" == "$1" ] || return 1
    footer="${1##*${__AS__ETX}}"
    [ "$footer" == "$1" ] || return 1

    # TODO: check also for structure characters
    return 0
}

__ason__is_structure() {
    header="${1%%${__AS__STX}*}"
    [ "$header" != "$1" ] || return 1
    footer="${1##*${__AS__ETX}}"
    [ "$footer" != "$1" ] || return 1

    [ "$header#${__AS__SOH}${_PAD}${__AS__US}" != "$header" ] || return 1
    [ "$footer%${__AS__EOD}" != "$footer" ] || return 1

    # TODO: check also proper nesting
    return 0
}

__ason__is_item() {
    __ason__is_structure || __ason__is_element
}

__ason__is_subscript() {
    return 1
}

__ason__is_slice_def() {
    return 1
}


# Metadata helpers

__ason__dim_slice_def() {
    # Get the dimensions of a slice_def, so we can test paste compatibility
    return 1
}

__ason__get_header_value() {
    headers="${1%%${__AS__STX}*}"
    headers="${headers#${__AS__SOH}*}"
    if [ "$headers" == "$1" ]; then
        printf "%s" "$_UNDEF"
        return 1
    fi
    while
        pair="${headers%%${__AS__RS}*}"
        key="${pair%%${__AS__US}*}"
        if [ "$key" == "$2" ]; then
            printf "%s" "${pair#*${__AS__US}}"
            return 0
        fi
    [ "$pair" != "$headers" ]; do
        # discard the first key/value pair
        headers="${headers#*${__AS__RS}}"
    done
    printf "%s" "$_UNDEF"
    return 0
}


# Construction helpers

__ason__pad() {
    printf "%s" "$_PAD$1$_PAD"
}

__ason__unpad() {
    printf "%s" "$1" \
        | sed 's/^[ \t]*//;s/[ \t]*$//' \
        | sed "s/^$_PAD*//;s/$_PAD*$//"
}

__ason__join() {
    pad="$1"; shift
    separator="$1"; shift
    item="${1:-}"
    if shift; then
        [ "$pad" != "pad" ] || __ason__pad "$item"
        for item in "$@"; do
            printf "%s" "$separator"
            [ "$pad" != "pad" ] || __ason__pad "$item"
        done
    fi
}

__ason__begin() {
    printf "%s" "$__AS__SOH$_PAD$__AS__US$1"
}

__ason__addheader() {
    printf "%s" "$__AS__RS${1:-}${__AS__US}${2:-}"
}

__ason__text() {
    printf "%s" "$__AS__STX"
}

__ason__footer() {
    printf "%s" "$__AS__ETX${1:-}$__AS__EOD"
}
