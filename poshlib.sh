################################################################################
# Initialise poshlib. Define the `use` command and reset USEPATH to default.
# All other features are optional and can be imported using `use`.
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
#
# . /path/to/poshlib/poshlib.sh
################################################################################

# Always clobber USEPATH; an inherited USEPATH can be used for shenanigans.
USEPATH=$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))

use() {
    local module="$1"; shift
    local dir
    local IFS=:
    for dir in $USEPATH; do
        if [ -f "$dir/$module.sh" ]; then
            source "$dir/$module.sh"
            return 0
        fi
    done
    echo "Could not find $1.sh in $USEPATH" 2>&1
    exit 101
}
