# shellcheck disable=SC2148
########################################################################
#
# Standard(ish) set of ANSI SGR macros for terminal colours etc.
#
# There are too many SGR options in ANSI; only implement the basics
#
########################################################################

# NB: setting text colours resets everything else; text colours must
# therefore be specified first. To explicitly reset, use $ANSI_RST
#
# Uppercase RGBCMYKW denote colours, bright colours are prefixed by B.
# Other attributes are indicated by lowercase suffixes.
#
# BEWARE that blue text and dark mode do not play nice. Avoid.


# Reset all
ANSI_RST=$'\033[0m'


# Common attributes (text colour). These include an ANSI_RST, and so must
# always be specified first in a sequence of attributes.

# Text colour
ANSI_K=$'\033[0;30m'
ANSI_R=$'\033[0;31m'
ANSI_G=$'\033[0;32m'
ANSI_Y=$'\033[0;33m'
ANSI_B=$'\033[0;34m'
ANSI_M=$'\033[0;35m'
ANSI_C=$'\033[0;36m'
ANSI_W=$'\033[0;37m'

# Bright text colour
ANSI_BK=$'\033[0;90m'
ANSI_BR=$'\033[0;91m'
ANSI_BG=$'\033[0;92m'
ANSI_BY=$'\033[0;93m'
ANSI_BB=$'\033[0;94m'
ANSI_BM=$'\033[0;95m'
ANSI_BC=$'\033[0;96m'
ANSI_BW=$'\033[0;97m'


# Additional attributes. These DO NOT include an ANSI_RST, so are cumulative.

# Bold
ANSI_bo=$'\033[1m'
# Faint
ANSI_ft=$'\033[2m'
# Underline
ANSI_ul=$'\033[4m'
# Blink
ANSI_bl=$'\033[5m'
# Strikeout
ANSI_so=$'\033[9m'

# Background colour
ANSI_Kbg=$'\033[40m'
ANSI_Rbg=$'\033[41m'
ANSI_Gbg=$'\033[42m'
ANSI_Ybg=$'\033[43m'
ANSI_Bbg=$'\033[44m'
ANSI_Mbg=$'\033[45m'
ANSI_Cbg=$'\033[46m'
ANSI_Wbg=$'\033[47m'

# Bright background colour
ANSI_BKbg=$'\033[100m'
ANSI_BRbg=$'\033[101m'
ANSI_BGbg=$'\033[102m'
ANSI_BYbg=$'\033[103m'
ANSI_BBbg=$'\033[104m'
ANSI_BMbg=$'\033[105m'
ANSI_BCbg=$'\033[106m'
ANSI_BWbg=$'\033[107m'

