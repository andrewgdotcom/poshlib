# shellcheck disable=SC2148
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
use tr
use wc

# Tests

__ason__is_plaintext_entity() {
    case "$1" in
    "$_UNDEF" | "$_TRUE" | "$_FALSE" | "$_DLE" | "$_PAD" | "$_PARA" )
        return 0
        ;;
    esac
    return 1
}

__ason__is_type_entity() {
    case "$1" in
    "$_QUOTE" | "$_LIST" | "$_OBJECT" | "$_DICT" | "$_TABLE" | "$_ARRAY" )
        return 0
        ;;
    esac
    return 1
}

__ason__is_entity() {
    __ason__is_plaintext_entity "$1" || __ason__is_type_entity "$1"
}

__ason__is_element() {
    __ason__header="${1%%"${__AS__STX}"*}"
    [ "$__ason__header" == "$1" ] || return 1

    # TODO: check also for structure characters
    return 0
}

__ason__is_structure() {
    __ason__header="${1%%"${__AS__STX}"*}"
    [ "$__ason__header" != "$1" ] || return 1

    [ "${__ason__header#"${__AS__SOH}${_PAD}${__AS__US}"}" != "$__ason__header" ] || return 1

    # TODO: check also proper nesting
    return 0
}

__ason__is_item() {
    __ason__is_structure "$1" || __ason__is_element "$1"
}

__ason__is_subscript() {
    echo "Not implemented"
    return 101
}

__ason__is_slice_def() {
    echo "Not implemented"
    return 101
}


# Metadata helpers

__ason__dim_slice_def() {
    # Get the dimensions of a slice_def, so we can test paste compatibility
    echo "Not implemented"
    return 101
}

__ason__get_header_keys() {
    __ason__header="${1%%"${__AS__STX}"*}"
    __ason__header="${__ason__header#*"${__AS__SOH}"}"
    if [ "$__ason__header" == "$1" ]; then
        printf "%s" "$_UNDEF"
        return 1
    fi
    __ason__begin_header "$_LIST"
    __ason__begin_text

    __ason__first=1
    while
        __ason__pair="${__ason__header%%"${__AS__RS}"*}"
        __ason__key="${__ason__pair%%"${__AS__US}"*}"
        [ -n "$__ason__first" ] || printf "%s" "$__AS__US"
        printf "%s" "$(__ason__wrap "$__ason__key")"
    [ "$__ason__pair" != "$__ason__header" ]; do
        # discard the first key/value pair
        __ason__header="${__ason__header#*"${__AS__RS}"}"
        __ason__first=
    done
    __ason__end
}

__ason__get_header_value() {
    __ason__header="${1%%"${__AS__STX}"*}"
    __ason__header="${__ason__header#*"${__AS__SOH}"}"
    if [ "$__ason__header" == "$1" ]; then
        printf "%s" "$_UNDEF"
        return 1
    fi
    while
        __ason__pair="${__ason__header%%"${__AS__RS}"*}"
        __ason__key="${__ason__pair%%"${__AS__US}"*}"
        if [ "$__ason__key" == "$2" ]; then
            printf "%s" "${__ason__pair#*"${__AS__US}"}"
            return 0
        fi
    [ "$__ason__pair" != "$__ason__header" ]; do
        # discard the first key/value pair
        __ason__header="${__ason__header#*"${__AS__RS}"}"
    done
    printf "%s" "$_UNDEF"
    return 0
}

__ason__get_stext() {
    # strip header and closing delimiter, which MUST exist
    __ason__temp="${1#*"${__AS__STX}"}"
    [ "$__ason__temp" != "$1" ] || return 1
    __ason__stext="${__ason__temp%"${__AS__ETX}"}"
    [ "$__ason__stext" != "$__ason__temp" ] || return 1
    printf "%s" "$__ason__stext"
}


# Construction helpers

__ason__wrap() {
    printf "%s" "$__AS__CAN$1$__AS__EM"
}

__ason__unwrap() {
    local re_leading="^([^${__AS__RESERVED}]*${__AS__CAN})"
    local re_trailing="(${__AS__EM}[^${__AS__RESERVED}]*)\$"
    local value=$1
    if [[ $value =~ $re_leading ]]; then
        value=${value#"${BASH_REMATCH[1]}"}
    fi
    if [[ $value =~ $re_trailing ]]; then
        value=${value%"${BASH_REMATCH[1]}"}
    fi
    printf "%s" "$value"
}

__ason__join() {
    __ason__wrap="$1"; shift
    __ason__separator="$1"; shift
    __ason__item="${1:-}"
    if shift; then
        [ "$__ason__wrap" != "pad" ] || __ason__wrap "$__ason__item"
        for __ason__item in "$@"; do
            printf "%s" "$__ason__separator"
            [ "$__ason__wrap" != "pad" ] || __ason__wrap "$__ason__item"
        done
    fi
}

__ason__begin_header() {
    printf "%s" "$__AS__SOH$_PAD$__AS__US$1"
}

__ason__add_metadata() {
    printf "%s" "$__AS__RS${1:-}${__AS__US}${2:-}"
}

__ason__begin_text() {
    printf "%s" "$__AS__STX"
}

__ason__end() {
    printf "%s" "$__AS__ETX"
}


# Iterator helpers

# __ason__to_next finds the next NON-NESTED appearance of $separator in
# $text and returns all the text leading up to it, EXCLUDING the separator.
# If there is no next separator, then it returns the entire text.
#
# NOTE that $text is NOT a whole structure; just the htext, stext, or ftext.
#
# Detecting the end of the stext is the calling routine's responsibility!
# The calling routine SHOULD invoke ${text#"$result"}, THEN test for empty, AND
# THEN invoke ${text#"$separator"}, because a trailing separator means that
# another value exists, but is the null string.

__ason__to_next() {
    __ason__separator="$1"; shift
    __ason__text="$1"; shift

    __ason__depth=0
    __ason__result=""
    while
        __ason__chunk="${__ason__text%%"${__ason__separator}"*}"
        __ason__result="${__ason__result}${__ason__chunk}"
        __ason__text="${__ason__text#*"${__ason__separator}"}"

        # find (number of __AS__SOH) minus (number of __AS__ETX) in chunk
        __ason__opens=$(wc.count "$__AS__SOH" <<< "$__ason__chunk")
        __ason__closes=$(wc.count "$__AS__ETX" <<< "$__ason__chunk")
        __ason__depth=$(( __ason__depth+__ason__opens-__ason__closes ))

        # if __ason__depth < 0, our ASON does not nest properly; abort
        [ "$__ason__depth" -ge 0 ] || return 1
    [ "$__ason__depth" != 0 ]; do
        # If we're going around again, reattach the separator
        __ason__result="$__ason__result$__ason__separator"
    done
    printf "%s" "$__ason__result"
}
