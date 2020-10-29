########################################################################
#
# Utility functions to manage structured data in ASON serialised format.
# This allows for arbitrary objects to be passed as string variables,
# or through pipelines.
#
# All functions are call by value, and are pure functions.
#
# It is advisable to also source/use the `ason-entities` file, in
# order to facilitate testing against entity output. 
#
# The functions can be divided into constructors, metrics, getters,
# conversions, and editors. These behave similarly across the different
# types of structure. All functions other than constructors can take the
# special value "-" as the first argument, in which case they operate on
# STDIN instead. 
#
# Note that all parameters SHOULD be quoted to prevent word-splitting.
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

########################################################################
#
# The following constructors are defined:
#
#   $(_LIST "$item1" [...])
#   $(_DICT "$keys" "$values")
#   $(_TABLE "$columns" "$values1" [...])
#
# If $keys (or $columns) is an element, it is paired with $values in a
# _DICT of length 1 (or _TABLE of width 1).
# If $keys ($columns) and $values(N) are _LISTs of equal length n, and the
# items in $keys ($columns) are distinct, then the _LISTs are combined
# per-item into a _DICT of length n (or _TABLE of width n).
#
########################################################################

_LIST() {
	
}

_DICT() {
	
}

_TABLE() {
	
}

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

_TYPE() {
	
}

_LENGTH() {
	
}

_WIDTH() {
	
}

########################################################################
#
# The following getters are defined for all structures:
#
#   $(_GET "$structure" ["$subscript"] ["$key"])
#   $(_VALUES "$structure")
#   $(_SPLIT "$structure")
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
# _SPLIT returns all the values in $structure as a whitespace-delimited
# list of quoted words suitable for shell word-splitting.
#
########################################################################


_GET() {
	
}

_VALUES() {
	
}

_SPLIT() {
	
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


_KEYS() {
	
}

_COLUMNS() {
	
}

_SLICE() {
	
}

_ROW() {
	
}

_COLUMN() {
	
}


########################################################################
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


_FOLIATE() {
	
}

_LAMINATE() {
	
}


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


_SET() {
	
}

_POP() {
	
}

_SHIFT() {
	
}

_PUSH() {
	
}

_UNSHIFT() {
	
}

_PASTE() {
	
}

_CUT() {
	
}

_CAT() {
	
}

_APPEND() {
	
}

_SETROW() {
	
}

_SETCOLUMN() {
	
}


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


_SELECT() {
	
}

_UPDATE() {
	
}

_DELETE() {
	
}

_ALTER() {
	
}

_SORT() {
	
}

_JOIN() {
	
}


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
