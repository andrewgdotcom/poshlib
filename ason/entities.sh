# ASON entity definitions

# The following MAY be used at the application plaintext level.
# Give them nice friendly names.

_UNDEF=$'\x05'  # ENQ
_TRUE=$'\x06'   # ACK
_FALSE=$'\x15'  # NAK
_PAD=$'\x16'    # SYN
_PARA=$'\x17'   # ETB

# The following MUST NOT be used at the application plaintext level.

__AS__SOH=$'\x01'
__AS__STX=$'\x02'
__AS__ETX=$'\x03'
__AS__EOT=$'\x04'

__AS__FS=$'\x1c'
__AS__GS=$'\x1d'
__AS__RS=$'\x1e'
__AS__US=$'\x1f'

# The following SHOULD NOT appear in ASON plaintext, but can be used as
# function return values for testing.

_QUOTE=$'\x10\x05'  # DLE_TC5
_LIST=$'\x10\x06'   # DLE_TC6
_DICT=$'\x10\x15'   # DLE_TC8
_TABLE=$'\x10\x16'  # DLE_TC9
_ARRAY=$'\x10\x17'  # DLE_TC10

# Reserve this for future use

__AS__SEQ__INIT=$'\x10\x10' # DLE_TC7

# The following MUST NOT be used ever. We define them here so that we can
# detect them and throw errors.

__AS__INVALID_DLE_TC1=$'\x10\x01'
__AS__INVALID_DLE_TC2=$'\x10\x02'
__AS__INVALID_DLE_TC3=$'\x10\x03'
__AS__INVALID_DLE_TC4=$'\x10\x04'
