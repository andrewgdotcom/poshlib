########################################################################
#
# Low-level ASON tools. No user-serviceable components inside.
#
########################################################################

use ason/entities

__ason__is_entity() {

}

__ason__is_element() {

}

__ason__is_structure() {

}

__ason__is_item() {

}

__ason__is_subscript() {

}

__ason__is_slice_def() {

}

__ason__dim_slice_def() {

}


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
        # remove any surrounding whitespace
        | __ason__unpad__temp=$(sed 's/^[ \t]*//;s/[ \t]*$//' \
        # remove any surrounding _PAD
        | sed "s/^$_PAD*//;s/$_PAD*$//"
}
