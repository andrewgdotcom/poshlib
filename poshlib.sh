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
USEPATH=

# Shell detector stolen from https://www.av8n.com/computer/shell-dialect-detect
shell_detect() { (
    res1=$(export PATH=/dev/null/$$
      type -p 2>/dev/null)
    st1="$?"

    res2=$(export PATH=/dev/null/$$
      type declare 2>/dev/null)
    st2="$?"        # not

    # this version works without sed, and indeed without a $PATH
    penult='nil'  ult=''
    for word in $(echo $res2) ; do
      penult="$ult"
      ult="$word"
    done

    tag="${st1}.${penult}_${ult}"
    case "${tag}" in
     0.shell_builtin) echo bash  ; exit ;;
       127.not_found) echo dash  ; exit ;;
              2.nil_) echo ksh93 ; exit ;;
     1.reserved_word) echo zsh5  ; exit ;;
    esac
) }

use() {
    local module="$1"; shift
    local dir
    local IFS=:
    if [ -z "$USEPATH" ]; then
        echo "You must define the envar USEPATH"
        exit 101
    fi
    for dir in $USEPATH; do
        if [ -f "$dir/$module.sh" ]; then
            . "$dir/$module.sh"
            return 0
        fi
    done
    echo "Could not find $1.sh in $USEPATH" 2>&1
    exit 101
}

# IFF we are using bash, we can initialise USEPATH automagically with bashisms.
# Otherwise, we must set USEPATH in the calling script.
# TODO: support other shells
if [ $(shell_detect) == "bash" ]; then
    USEPATH=$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))
fi
