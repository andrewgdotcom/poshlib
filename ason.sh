# shellcheck disable=SC2148
########################################################################
#
# Utility functions to manage structured data in ASON serialised format.
# This allows for arbitrary objects to be passed as string variables,
# or through pipelines.
#
# The functions can be divided into constructors, metrics, getters,
# conversions, and editors. These behave similarly across the different
# types of structure.
#
# Note that all parameters and substitutions SHOULD be quoted to prevent
# word-splitting.
#
# See ason/lowlevel for a fuller explanation of terminology.
#
########################################################################

use ason/entities

########################################################################
#
# _REVEAL substitutes ASON entities with their shell expansions
#
########################################################################

_REVEAL() {(
    use strict
    use utils
    string="$1"; shift

    # First substitute structure characters
    for entityvar in __AS__SOH __AS__STX __AS__ETX \
            __AS__CAN __AS__EM \
            __AS__FS __AS__GS __AS__RS __AS__US; do
        # we can't replace this with shell native if we want to support bash 3.2
        # shellcheck disable=SC2001
        string=$(sed "s/${!entityvar}/\\$\\{${entityvar}\\}/g" <<< "$string")
    done

    # substitute the longer entities first, to prevent partial matches
    for entityvar in _QUOTE _LIST _OBJECT _DICT _TABLE _ARRAY \
            _UNDEF _TRUE _DLE _FALSE _PAD _PARA; do
        # we can't replace this with shell native if we want to support bash 3.2
        # shellcheck disable=SC2001
        string=$(sed "s/${!entityvar}/\\$\\{${entityvar}\\}/g" <<< "$string")
    done
    printf "%s" "$string"
)}


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
#
# If $keys ($columns) and $valuesN are _LISTs of equal length n, and the
# items in $keys ($columns) are distinct, then the _LISTs are combined
# per-item into a _DICT of length n (or _TABLE of width n).
#
########################################################################


_QUOTE() {(
    use strict
    use utils
    use ason/lowlevel

    string="$1"
    __ason__begin_header "$_QUOTE"
    __ason__begin_text
    __ason__wrap "$string"
    __ason__end
)}

_LIST() {(
    use strict
    use utils
    use ason/lowlevel

    __ason__begin_header "$_LIST"
    __ason__begin_text
    if [ "${1-$_UNDEF}" == "$_UNDEF" ]; then
        printf "%s" "$_UNDEF"
    else
        __ason__join "pad" "$__AS__US" "$@"
    fi
    __ason__end
)}

_DICT() {(
    use strict
    use utils
    use ason/lowlevel

    __ason__begin_header "$_DICT"
    __ason__begin_text

    if [ "${1-$_UNDEF}" = "$_UNDEF" ]; then
        printf "%s" "$_UNDEF"
    else
        [ "$(_TYPE "$1")" == "$_LIST" ] || die 2 "Argument 1 not a list"
        keys=$(__ason__get_stext "$1" || die 2 "Invalid structure 1"); shift
        [ "$(_TYPE "$1")" == "$_LIST" ] || die 2 "Argument 2 not a list"
        values=$(__ason__get_stext "$1" || die 2 "Invalid structure 2"); shift
        start=1
        last=
        key=
        value=
        while [ -z "$last" ]; do
            key="$(__ason__to_next "$__AS__US" "$keys")"
            # remove the found item and any subsequent separator
            keys="${keys#"$key"}"
            [ -n "$keys" ] || last=1
            keys="${keys#"$__AS__US"}"
            value="$(__ason__to_next "$__AS__US" "$values")"
            # remove the found item and any subsequent separator
            values="${values#"$value"}"
            [ -n "$values" ] || last=1
            values="${values#"$__AS__US"}"
            if [ -z "$start" ]; then
                printf "%s" "$__AS__RS"
            else
                start=''
            fi
            printf "%s" "$key$__AS__US$value"
        done
    fi

    __ason__end

    if [ -n "$keys" ] || [ -n "$values" ]; then
        die 1 "Lists not the same length"
    fi
)}

_TABLE() {(
    use strict
    use utils
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
#
# _LENGTH returns the number of values in a _LIST or _DICT; or the
# number of rows in a _TABLE.
#
# The following metrics are defined only for _TABLEs:
#
#   $(_WIDTH "$table")
#
# _WIDTH returns the number of columns in a table. It is equivalent to
# $(_LENGTH "$(_COLUMNS "$table")")
#
########################################################################


_TYPE() {(
    use strict
    use utils
    use ason/lowlevel

    __ason__get_header_value "$1" "$_PAD"
)}

_LENGTH() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" | "$_DICT" )
        separator="$__AS__US"
        [ "$type" == "$_LIST" ] || separator="$__AS__RS"
        stext=$(__ason__get_stext "$structure" || die 2 "Invalid structure")
        count=0
        item=
        while true; do
            item="$(__ason__to_next "$separator" "$stext")"
            [ "$item" != "$_UNDEF" ] || break
            (( ++count ))
            stext="${stext#"$item"}"
            [ -n "$stext" ] || break
            stext="${stext#"$separator"}"
        done
        printf "%s" "$count"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

_WIDTH() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_TABLE" )
        die 101 "_WIDTH _TABLE not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}


########################################################################
#
# The following getters are defined for all structures:
#
#   $(_GET "$structure" ["$subscript"] ["$key"])
#   $(_VALUES "$structure")
#
# _GET returns a single value from the structure.
# If the parent structure is a _LIST, only $subscript is given.
# If the parent structure is a _DICT, only $key is given.
# If the parent structure is a _TABLE, both are given in the order
# row, column ($subscript, $key).
# If _GET is passed an invalid $subscript or $key, it returns $_UNDEF
# and a nonzero exit code.
#
# _VALUES returns all the values in $structure as a flat _LIST. If
# $structure is itself a _LIST, it returns its argument unchanged.
#
# The following getters are defined for _LISTs:
#
#   _READ var "$structure"
#   _FOREACH var [in] "$structure" command [args...]
#
# _READ assigns the values of a _LIST to the array `var` in the calling
# context; it is analogous to `read -a var <<< "$input"`.
#
# _FOREACH runs the supplied command with `var` set to each member of
# the list in turn. The command must be a one-liner.
#
########################################################################


_GET() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        subscript="$1"; shift
        stext=$(__ason__get_stext "$structure" || die 2 "Invalid structure")
        count=0
        item="$_UNDEF"
        while [ "$count" -lt "$subscript" ]; do
            item="$(__ason__to_next "$__AS__US" "$stext")"
            (( ++count ))
            # remove the found item and any subsequent separator
            stext="${stext#"$item"}"
            [ -n "$stext" ] || break
            stext="${stext#"$__AS__US"}"
        done
        if [ "$count" = "$subscript" ]; then
            printf "%s" "$(__ason__unwrap "$item")"
        else
            printf "%s" "$_UNDEF"
        fi
        ;;
    "$_DICT" )
#        key="$1"; shift
        die 101 "_GET _DICT Not implemented"
        ;;
    "$_TABLE" )
#        subscript="$1"; shift
#        key="$1"; shift
        die 101 "_GET _TABLE Not implemented"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

_VALUES() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        say "$structure"
        ;;
    "$_DICT" )
        die 101 "_VALUES _DICT Not implemented"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

__READ_NOEVAL() {(
    use strict
    use utils
    use ason/lowlevel
    varname="$1"; shift
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        stext=$(__ason__get_stext "$structure" || die 2 "Invalid structure")
        printf "%s" "$varname=("
        while true; do
            item=$(__ason__to_next "$__AS__US" "$stext")
            printf " %q" "$(__ason__unwrap "$item")"
            stext="${stext#"$item"}"
            [ -n "$stext" ] || break
            stext="${stext#"$__AS__US"}"
        done
        printf " )"
        ;;
    "$_DICT" | "$_TABLE" | "$_ARRAY" )
        # Call _VALUES to convert to list, and recurse
        # TODO: This is inefficient, so rewrite at some point
        __READ_NOEVAL "$(_VALUES "$structure")"
        ;;
    * )
        die 101 "Not implemented"
        ;;
    esac
)}

_READ() {
    eval "$(__READ_NOEVAL "$@")"
}

_FOREACH() {
    die 101 "Not implemented"
}


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
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_DICT" )
        die 101 "_KEYS _DICT Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_COLUMNS() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_SLICE() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_SLICE _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_ROW() {
    use strict
    use utils
    die 101 "Not implemented"
}

_COLUMN() {(
    use strict
    use utils
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
    use strict
    use utils

    separator="$1"; shift
    string="$1"; shift
    IFS="$separator" read -r -a words <<< "$string"
    # Ultra-safe bash array expansion
    # https://gist.github.com/dimo414/2fb052d230654cc0c25e9e41a9651ebe
    _LIST ${words[@]+"${words[@]}"}
)}

_FOLIATE() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_LAMINATE() {(
    use strict
    use utils
    die 101 "Not implemented"
)}


########################################################################
#
# The following editors are defined for _LISTs, _DICTs, and _TABLEs:
#
#   $(_SET "$structure" ["$subscript"] ["$key"] = "$item")
#
# Note that the "=" is syntactic sugar but is included to trap errors.
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
#
# The $structureN arguments to _CAT must be of the same type, and if they
# are _TABLEs the keys must be identical.
# _CAT does not merge headers; the headers of the first argument are used
#
# The following editors are defined for _DICTs:
#
#   $(_APPEND "$dict1" [...])
#
# If the keys of the $dictN are not distinct, _JOIN must be used instead.
#
# The following editors are defined for _TABLEs:
#
#   $(_SETROW "$table" "$subscript" = "$list")
#   $(_SETCOLUMN "$table" "$column" = "$list")
#
# _SETROW takes a _LIST as its rvalue, while _PASTE takes a _TABLE.
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
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_SET _LIST Not implemented"
        ;;
    "$_DICT" )
        die 101 "_SET _DICT Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_POP() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_POP _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_SHIFT() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_SHIFT _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_PUSH() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_PUSH _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_UNSHIFT() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_UNSHIFT _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_PASTE() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_PASTE _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_CUT() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_CUT _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_CAT() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_LIST" )
        die 101 "_CAT _LIST Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_APPEND() {(
    use strict
    use utils
    use ason/lowlevel
    structure="$1"; shift
    type="$(_TYPE "$structure")"

    case "$type" in
    "$_DICT" )
        die 101 "_APPEND _DICT Not implemented"
        ;;
    *)
        die 101 "Not implemented"
        ;;
    esac
)}

_SETROW() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_SETCOLUMN() {(
    use strict
    use utils
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
    use strict
    use utils
    die 101 "Not implemented"
)}

_UPDATE() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_DELETE() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_ALTER() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_SORT() {(
    use strict
    use utils
    die 101 "Not implemented"
)}

_JOIN() {(
    use strict
    use utils
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
