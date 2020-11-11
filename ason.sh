########################################################################
#
# Utility functions to manage structured data in ASON serialised format.
# This allows for arbitrary objects to be passed as string variables,
# or through pipelines.
#
# All functions are call by value, and are pure functions.
#
# The functions can be divided into constructors, metrics, getters,
# conversions, and editors. These behave similarly across the different
# types of structure.
#
# Note that all parameters SHOULD be quoted to prevent word-splitting.
#
# See ason/lowlevel for an explanation of terminology.
#
########################################################################

use ason/entities

########################################################################
#
# The following constructors are defined:
#
#   $(_QUOTE "$string")
#   $(_LIST "$item1" [...])
#   $(_DICT "$keys" "$values")
#   $(_TABLE "$columns" "$values1" [...])
#
# If $keys (or $columns) is an element, it is paired with $values in a
# _DICT of length 1 (or _TABLE of width 1).
# If $keys ($columns) and $valuesN are _LISTs of equal length n, and the
# items in $keys ($columns) are distinct, then the _LISTs are combined
# per-item into a _DICT of length n (or _TABLE of width n).
#
########################################################################


_QUOTE() {(
    use swine
    use ason/lowlevel

    string="$1"
    __ason__begin "$_QUOTE"
    __ason__text
    __ason__pad "$string"
    __ason__footer ""
)}

_LIST() {(
    use swine
    use ason/lowlevel

    __ason__begin "$_LIST"
    __ason__text
    __ason__join "pad" "$__AS__US" "$@"
    __ason__footer ""
)}

_DICT() {(
    use swine
    die 101 "Not implemented"
)}

_TABLE() {(
    use swine
    die 101 "Not implemented"
)}


########################################################################
#
# The following metrics are defined on all structures:
#
#   $(_TYPE "$structure")
#   $(_LENGTH "$structure")
#
# _TYPE returns an entity that identifies the type of $structure.
# _LENGTH returns the number of values in a _LIST or _DICT; or the
# number of rows in a _TABLE.
#
# The following metrics are defined only for _TABLEs:
#
#   $(_WIDTH "$table")
#
# _WIDTH returns the number of columns in a table. It is equivalent to
# $(_LENGTH $(_COLUMNS "$table"))
#
########################################################################


_TYPE() {(
    use swine
    use ason/lowlevel

    __ason__get_header_value "$1" "$_PAD"
)}

_LENGTH() {(
    use swine
    use ason/lowlevel


)}

_WIDTH() {(
    use swine
    use ason/lowlevel

    [ "$(_TYPE "$1")" == "$_DICT" ] || die 1 "_WIDTH not defined for non-DICTs"


)}


########################################################################
#
# The following getters are defined for all structures:
#
#   $(_GET "$structure" ["$subscript"] ["$key"])
#   $(_VALUES "$structure")
#   $(_READ var "$structure")
#
# _GET returns a single value from the structure.
# If the parent structure is a _LIST, only $subscript is given.
# If the parent structure is a _DICT, only $key is given.
# If the parent structure is a _TABLE, both are given in the order
# row, column ($subscript, $key).
# If _GET is passed an invalid $subscript or $key, it returns $_UNDEF and a
# nonzero exit code.
# _VALUES returns all the values in $structure as a flat _LIST. If
# $structure is itself a _LIST, it returns its argument unchanged.
# _READ returns a snippet of shell code suitable for passing to `eval`, which
# assigns the values of a _LIST to the array `var`
#
########################################################################


_GET() {(
    use swine
    use ason/lowlevel
    structure="$1"

    case "$(_TYPE "$structure")" in
    "$_LIST" )
        subscript="$2"

        # operate on stext only
        structure="${structure#*$__AS__STX}"
        structure="${structure%$__AS__ETX*}"

        count=0
        item=
        while [ "$count" -lt "$subscript" ] && [ -n "$structure" ]; do
            item="$(__ason__to_next "$__AS__US" "$structure")"
            structure="${structure#$item}"
            (( ++count ))
        done
        if [ -n "$item" ]; then
            printf "%s" "$(__ason__unpad "$item")"
        else
            printf "%s" "$_UNDEF"
        fi
        ;;
    "$_DICT" )
        key="$2"
        die 101 "Not implemented"
        ;;
    "$_TABLE" )
        subscript="$2"
        key="$3"
        die 101 "Not implemented"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

_VALUES() {(
    use swine
    use ason/lowlevel
    structure="$1"

    case "$(_TYPE "$structure")" in
    "$_LIST" )
        say "$structure"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

_READ() {(
    use swine
    use ason/lowlevel
    varname="$1"; shift
    structure="$1"; shift

    case "$(_TYPE "$structure")" in
    "$_LIST" )
        # operate on stext only
        structure="${structure#*$__AS__STX}"
        structure="${structure%$__AS__ETX*}"

        printf "%s" "$varname=("
        while [ -n "$structure" ]; do
            item=$(__ason__to_next "$__AS__US" "$structure")
            printf " %q" "$(__ason__unpad "$item")"
            structure="${structure#$item}"
            # the following is a no-op after the last item
            structure="${structure#$__AS__US}"
        done
        printf " )"
        ;;
    "$_DICT" | "$_TABLE" | "$_ARRAY" )
        # Call _VALUES to convert to list, and recurse
        # TODO: This is inefficient, so rewrite at some point
        _READ "$(_VALUES "$structure")"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

########################################################################
#
# The following getters are defined for _DICTs:
#
#   $(_KEYS "$structure")
#
# _KEYS returns a _LIST of the keys of a _DICT.
#
# The following getters are defined for _TABLEs:
#
#   $(_COLUMNS "$structure")
#
# The following getters are defined for _LISTs and _TABLEs:
#
#   $(_SLICE "$structure" "$slice_def")
#
# _SLICE returns a structure of the same type as its argument but smaller
# dimensions.
# If it is passed an invalid slice_def, it returns an empty structure and
# a nonzero return code.
#
# The following getters are defined for _TABLEs:
#
#   $(_ROW "$table" "$subscript")
#   $(_COLUMN "$table" "$key")
#
# _ROW returns a _DICT of $(_COLUMNS "$table") and one row of values.
# _COLUMN returns a _LIST of all the values corresponding to $column.
#
########################################################################


_KEYS() {(
    use swine
    die 101 "Not implemented"
)}

_COLUMNS() {(
    use swine
    die 101 "Not implemented"
)}

_SLICE() {(
    use swine
    die 101 "Not implemented"
)}

_ROW() {
    use swine
    die 101 "Not implemented"
}

_COLUMN() {(
    use swine
    die 101 "Not implemented"
)}


########################################################################
#
# The following conversions are defined for _LISTs:
#
#   $(_SPLIT "$separator" "$string")
#
# _SPLIT returns a _LIST of strings, where $string is split on $separator.
#
# The following conversions are defined for _TABLEs:
#
#   $(_FOLIATE "$table")
#   $(_LAMINATE "$list_of_dicts")
#
# _FOLIATE returns a _LIST of _DICTs, one for each row.
# _LAMINATE is its inverse. $list_of_dicts is a _LIST of _DICTs, and
# each _DICT MUST have the same set of keys.
#
########################################################################


_SPLIT() {(
    use swine

    separator="$1"; shift
    string="$1"; shift
    IFS="$separator" read -r -a words <<< "$string"
    _LIST "${words[@]}"
)}

_FOLIATE() {(
    use swine
    die 101 "Not implemented"
)}

_LAMINATE() {(
    use swine
    die 101 "Not implemented"
)}


########################################################################
#
# The following editors are defined for _LISTs, _DICTs, and _TABLEs:
#
#   $(_SET "$structure" ["$subscript"] ["$key"] = "$item")
#
# Note that the "=" is syntactic sugar but is required to minimise errors.
#
# The following editors are defined for _LISTs and _TABLEs:
#
#   $(_POP "$structure" ["$count"])
#   $(_SHIFT "$structure" ["$count"])
#   $(_PUSH "$structure" "$item" [...])
#   $(_UNSHIFT "$structure" "$item" [...])
#
#   $(_PASTE "$structure" "$slice_def" = "$new_slice")
#   $(_CUT "$structure" "$slice_def")
#
#   $(_CAT "$structure1" [...])
#
# _PUSH and _POP operate on the last item (or row) of the structure, while
# _SHIFT and _UNSHIFT operate on the first. If $count is given, that number
# of items is _POPped or _SHIFTed.
#
# $new_slice MUST be of the same type as $structure, and the same
# dimensions as $slice_def.
# The $structureN arguments to _CAT must be of the same type, and if they
# are _TABLEs the keys must be identical.
# If the first argument to _CAT is "-" then one or more structures are read
# from STDIN and any further arguments are appended to them.
#
# The following editors are defined for _DICTs:
#
#   $(_APPEND "$dict1" [...])
#
# If the keys of the $dictN are not distinct, _JOIN must be used instead.
#
# The following editors are defined for _TABLEs:
#
#   $(_SETROW "$table" "$subscript" = "$dict")
#   $(_SETCOLUMN "$table" "$column" = "$list")
#
# _SETROW takes a _DICT as its rvalue, while _PASTE takes a _TABLE.
#
# Editors always return a structure of the same type as the first argument.
# If any editor removes the last item in a structure, it successfully
# returns an empty structure.
# If an edit cannot be performed due to an invalid subscript, key, or
# slice_def, the editor will return its structure argument unchanged,
# but with a nonzero return code.
#
########################################################################


_SET() {(
    use swine
    die 101 "Not implemented"
)}

_POP() {(
    use swine
    die 101 "Not implemented"
)}

_SHIFT() {(
    use swine
    die 101 "Not implemented"
)}

_PUSH() {(
    use swine
    die 101 "Not implemented"
)}

_UNSHIFT() {(
    use swine
    die 101 "Not implemented"
)}

_PASTE() {(
    use swine
    die 101 "Not implemented"
)}

_CUT() {(
    use swine
    die 101 "Not implemented"
)}

_CAT() {(
    use swine
    die 101 "Not implemented"
)}

_APPEND() {(
    use swine
    die 101 "Not implemented"
)}

_SETROW() {(
    use swine
    die 101 "Not implemented"
)}

_SETCOLUMN() {(
    use swine
    die 101 "Not implemented"
)}


########################################################################
#
# Advanced _TABLE functions:
#
#   $(_SELECT "$columns" from "$table" where "$condition")
#   $(_UPDATE "$table" "$columns" = "$values" where "$condition")
#   $(_DELETE "$table" where "$condition")
#   $(_ALTER "$table" (add|drop) "$column" [...])
#
# If $columns is an element, then _SELECT returns a _LIST of values.
# If $columns is a _LIST then _SELECT returns a _TABLE.
# The $columns and $values arguments to _UPDATE must either both be
# elements, or _LISTs of the same length.
#
# Multipass _TABLE functions:
#
#   $(_SORT "$table" by "$condition")
#   $(_JOIN "$table" [...] where "$condition")
#
# Table joins cannot be written as stream functions, as the arguments
# need to be sorted.
#
########################################################################


_SELECT() {(
    use swine
    die 101 "Not implemented"
)}

_UPDATE() {(
    use swine
    die 101 "Not implemented"
)}

_DELETE() {(
    use swine
    die 101 "Not implemented"
)}

_ALTER() {(
    use swine
    die 101 "Not implemented"
)}

_SORT() {(
    use swine
    die 101 "Not implemented"
)}

_JOIN() {(
    use swine
    die 101 "Not implemented"
)}


########################################################################
#
# _ARRAY (provisional)
#
# The following constructors are defined for _ARRAYs:
#
#   $(_ARRAY "$item" [...])
#   $(_ARRAY_OF_ARRAYS "$array1" [...])
#
# where if the $itemN arguments to _ARRAY are _ARRAYs of rank n, they are
# laminated into a single _ARRAY of rank n+1, otherwise they are treated
# as items in an _ARRAY of rank 1. To prevent lamination, use
# _ARRAY_OF_ARRAYS instead.
#
# The following metrics are defined only for _ARRAYs:
#
#   $(_RANK "$array")
#   $(_DIM "$array")
#
# _RANK returns a positive integer indicating the rank of $array and _DIM
# returns a _LIST of numbers indicating the dimensions of $array.
# _RANK is equal to $(_LENGTH $(_DIM "$array"))
#
# The following getters are extended to _ARRAYs:
#
#   $(_GET "$array" "$subscript1" [...])
#   $(_VALUES "$array")
#   $(_SPLIT "$array")
#   $(_SLICE "$array" "$slice_def1" [...])
#   $(_PASTE "$structure" "$slice_def1" [...] = "$new_slice")
#   $(_CUT "$structure" "$slice_def1" [...])
#
# where the number of $subscriptN and $slice_defN MUST equal the rank.
# Only one $slice_def argument to _CUT may be bounded.
#
# The following conversions are extended:
#
#   $(_FOLIATE "$array" ["$max_depth"])
#   $(_LAMINATE "$list_of_lists" ["$max_depth"])
#
# _FOLIATE returns a _LIST of items, each of which may be another _LIST,
# recursively applied $(_RANK "$table") times, unless $max_depth is given,
# in which case the hierarchy ends in a _LIST of _ARRAYs of rank
# ($(_RANK "$table") - $max_depth). The inverse logic applies to _LAMINATE,
# except the lamination continues into the first level of _ARRAY items.
# Each _ARRAY in the last _LIST is laminated into the output _ARRAY, but
# this does not continue into any _LIST or _ARRAY items therein.
#
# The following editors are extended to arrays:
#
#   $(_SET "$array" "$subscript1" [...] = "$item")
#   $(_PASTE "$array" "$slice_def1" [...] = "$new_slice")
#
########################################################################
