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
    __ason__header="${1%%${__AS__STX}*}"
    [ "$__ason__header" == "$1" ] || return 1
    __ason__footer="${1##*${__AS__ETX}}"
    [ "$__ason__footer" == "$1" ] || return 1

    # TODO: check also for structure characters
    return 0
}

__ason__is_structure() {
    __ason__header="${1%%${__AS__STX}*}"
    [ "$__ason__header" != "$1" ] || return 1
    __ason__footer="${1##*${__AS__ETX}}"
    [ "$__ason__footer" != "$1" ] || return 1

    [ "$__ason__header#${__AS__SOH}${_PAD}${__AS__US}" != "$__ason__header" ] || return 1
    [ "$__ason__footer%${__AS__EOD}" != "$__ason__footer" ] || return 1

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
    __ason__header="${1%%${__AS__STX}*}"
    __ason__header="${__ason__header#${__AS__SOH}*}"
    if [ "$__ason__header" == "$1" ]; then
        printf "%s" "$_UNDEF"
        return 1
    fi
    while
        __ason__pair="${__ason__header%%${__AS__RS}*}"
        __ason__key="${__ason__pair%%${__AS__US}*}"
        if [ "$__ason__key" == "$2" ]; then
            printf "%s" "${__ason__pair#*${__AS__US}}"
            return 0
        fi
    [ "$__ason__pair" != "$__ason__header" ]; do
        # discard the first key/value pair
        __ason__header="${__ason__header#*${__AS__RS}}"
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
    __ason__pad="$1"; shift
    __ason__separator="$1"; shift
    __ason__item="${1:-}"
    if shift; then
        [ "$__ason__pad" != "pad" ] || __ason__pad "$__ason__item"
        for __ason__item in "$@"; do
            printf "%s" "$__ason__separator"
            [ "$__ason__pad" != "pad" ] || __ason__pad "$__ason__item"
        done
    fi
}

__ason__begin() {
    printf "%s" "$__AS__SOH$_PAD$__AS__US$1"
}

__ason__add_pair() {
    printf "%s" "$__AS__RS${1:-}${__AS__US}${2:-}"
}

__ason__text() {
    printf "%s" "$__AS__STX"
}

__ason__footer() {
    printf "%s" "$__AS__ETX${1:-}$__AS__EOD"
}
