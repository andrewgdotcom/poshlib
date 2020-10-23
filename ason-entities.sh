# ASON entity definitions

# The following MAY be used at the application plaintext level.
# Give them nice friendly names.

_UNDEF=$'\x05'  # ENQ
_TRUE=$'\x06'   # ACK
_FALSE=$'\x15'  # NAK
_PAD=$'\x16'    # SYN
_PARA=$'\x17'   # ETB

# The following MUST NOT be used at the application plaintext level.
# Some are reserved for future use and will be given proper names when
# appropriate.

__AS__SOH=$'\x01'
__AS__STX=$'\x02'
__AS__ETX=$'\x03'
__AS__EOD=$'\x04'

__AS__FS=$'\x1c'
__AS__GS=$'\x1d'
__AS__RS=$'\x1e'
__AS__US=$'\x1f'

__AS__RESERVED__TC5=$'\x10\x05'
__AS__RESERVED__TC6=$'\x10\x06'

__AS__SEQ__INIT=$'\x10\x10' # TC7
__AS__DICT=$'\x10\x15'  # TC8
__AS__TABLE=$'\x10\x16' # TC9
__AS__ARRAY=$'\x10\x17' # TC10

# The following MUST NOT be used ever. We define them here so that we can
# detect them and throw errors.

__AS__INVALID__TC1=$'\x10\x01'
__AS__INVALID__TC2=$'\x10\x02'
__AS__INVALID__TC3=$'\x10\x03'
__AS__INVALID__TC4=$'\x10\x04'
