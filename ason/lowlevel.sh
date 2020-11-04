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
        exit 0
        ;;
    esac
    exit 1
}

__ason__is_type_entity() {
    case "$1" in
    "$_QUOTE" | "$_LIST" | "$_DICT" | "$_TABLE" | "$_ARRAY" )
        exit 0
        ;;
    esac
    exit 1
}

__ason__is_entity() {
    __ason__is_plaintext_entity || __ason__is_type_entity
}

__ason__is_element() {
    exit 1
}

__ason__is_structure() {
    exit 1
}

__ason__is_item() {
    __ason__is_structure || __ason__is_element
}

__ason__is_subscript() {
    exit 1
}

__ason__is_slice_def() {
    exit 1
}


# Test helpers

__ason__dim_slice_def() {
    # Get the dimensions of a slice_def, so we can test paste compatibility
    exit 1
}


# Construction helpers

__ason__begin() {
    echo -E -n "$__AS__SOH$_PAD$__AS__US$1"
}

__ason__addheader() {
    echo -E -n "$__AS__RS${1:-}"
}

__ason__text() {
    echo -E -n "$__AS__STX"
}

__ason__footer() {
    echo -E "$__AS__ETX${1:-}$__AS__EOD"
}

__ason__pad() {
    echo -E -n "$_PAD$1$_PAD"
}

__ason__unpad() {
    echo -E "$1" \
        | sed 's/^[ \t]*//;s/[ \t]*$//' \
        | sed "s/^$_PAD*//;s/$_PAD*$//"
}
