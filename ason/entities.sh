# shellcheck disable=SC2148
# ASON entity definitions

# The following MAY be used at the application plaintext level.
# Give them nice friendly names.

_UNDEF=$'\x05'  # ENQ
_TRUE=$'\x06'   # ACK
_DLE=$'\x10'    # DLE
_FALSE=$'\x15'  # NAK
_PAD=$'\x16'    # SYN
_PARA=$'\x17'   # ETB

# The following MUST NOT be used at the application plaintext level.

__AS__SOH=$'\x01'
__AS__STX=$'\x02'
__AS__ETX=$'\x03'
__AS__EOT=$'\x04'

__AS__CAN=$'\x18'
__AS__EM=$'\x19'

__AS__FS=$'\x1c'
__AS__GS=$'\x1d'
__AS__RS=$'\x1e'
__AS__US=$'\x1f'

# The following can be used as function return values for testing.

_QUOTE=$'\x10\x05'  # DLE_TC5
_LIST=$'\x10\x06'   # DLE_TC6
_OBJECT=$'\x10\x10' # DLE_TC7
_DICT=$'\x10\x15'   # DLE_TC8
_TABLE=$'\x10\x16'  # DLE_TC9
_ARRAY=$'\x10\x17'  # DLE_TC10

# The following MUST NOT be used ever.
# We define them here so that we can detect them and throw errors.

__AS__INVALID_DLE_TC1=$'\x10\x01'
__AS__INVALID_DLE_TC2=$'\x10\x02'
__AS__INVALID_DLE_TC3=$'\x10\x03'
__AS__INVALID_DLE_TC4=$'\x10\x04'

__AS__INVALID_NUL=$'\x00'
__AS__INVALID_DC1=$'\x11'
__AS__INVALID_DC2=$'\x12'
__AS__INVALID_DC3=$'\x13'
__AS__INVALID_DC4=$'\x14'
__AS__INVALID_SUB=$'\x1a'

# Define some useful regex templates

# Reserved characters are the list of forbidden, structure and excision characters
__AS__RESERVED="$__AS__SOH$__AS__STX$__AS__ETX$__AS__EOT$__AS__CAN$__AS__EM$__AS__FS$__AS__GS$__AS__RS$__AS__US$__AS__INVALID_NUL$__AS__INVALID_DC1$__AS__INVALID_DC2$__AS__INVALID_DC3$__AS__INVALID_DC4$__AS__INVALID_SUB"
