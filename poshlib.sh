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
detect_shell() { (
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
    echo "Could not find ${module}.sh in $USEPATH" 2>&1
    exit 101
}

declare_main() {
    if [ $(detect_shell) == "bash" ]; then
        # We expect to be in the second level of the bash call stack.
        # If we are any deeper, then the calling code is not at the top.
        # If it is not at the top, then it MUST NOT invoke a main function.
        if [ -n "${BASH_SOURCE[2]}" ]; then
            return 0
        fi
    else
        echo "Shell not supported" >&2
        return 1
    fi
    "$@"
}

# IFF we are using bash, we can initialise USEPATH automagically with bashisms.
# Otherwise, we must set USEPATH in the calling script.
# TODO: support other shells
if [ $(detect_shell) == "bash" ]; then
    USEPATH=$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))
fi
