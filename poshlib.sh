################################################################################
# Initialise poshlib. Define the `use` command and reset USEPATH to default.
# All other features are optional and can be imported using `use`.
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
#
# . /path/to/poshlib/poshlib.sh || exit 1
################################################################################

# Avoid reinitialization
if [ "${__posh__stacktrace:-}" == "" ]; then
    # Initialize a stacktrace
    __posh__stacktrace="."

    # Shell detector stolen from https://www.av8n.com/computer/shell-dialect-detect
    __posh__detected__shell="$( (
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
    ) )"
    [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: detected shell=$__posh__detected__shell" >&2

    # Always clobber USEPATH; an inherited USEPATH can be used for shenanigans.
    USEPATH=
    # IFF we are using bash, we can initialise USEPATH automagically with bashisms.
    # Otherwise, we must set USEPATH in the calling script.
    # TODO: support other shells
    if [ "$__posh__detected__shell" == "bash" ]; then
        USEPATH=$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))
    fi
fi

__posh__descend() {
    local action="$1"; shift
    local module="$1"; shift
    local dir
    local IFS=:
    if [ "$action" != "." ]; then
        pathvariable=__POSH__${action}__PATH
        descendpath="${!pathvariable}"
    elif [ -n "$USEPATH" ]; then
        descendpath="$USEPATH"
    else
        echo "# POSH_ERROR: You must define the envar USEPATH" >&2
        exit 101
    fi
    for dir in $descendpath; do
        if [ -f "$dir/$module.sh" ]; then
            local safe_module=$(echo "$dir/$module.sh" | tr : _)
            # prevent loops
            [ "${__posh__stacktrace%:$safe_module}" == "$__posh__stacktrace" ] || return 0
            [ "${__posh__stacktrace%:$safe_module:*}" == "$__posh__stacktrace" ] || return 0
            __posh__stacktrace="$__posh__stacktrace:$safe_module"
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: >> $__posh__stacktrace" >&2
            "$action" "$dir/$module.sh"
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: << $__posh__stacktrace" >&2
            __posh__stacktrace="${__posh__stacktrace%:*}"
            return 0
        fi
    done
    echo "# POSH_ERROR: Could not find ${module}.sh in $descendpath" >&2
    exit 101
}

__posh__prependpath() {
    local __PPPP__varname="$1"; shift
    local __PPPP__path="$1"; shift
    # make paths relative to script location, not PWD
    if [ "$__posh__detected__shell" == "bash" ]; then
        if [ "${__PPPP__path#../}" != "$__PPPP__path" -o "${__PPPP__path#./}" != "$__PPPP__path" ]; then
            __PPPP__path="${__posh__stacktrace##*:}/${__PPPP__path#./}"
        elif [ "$__PPPP__path" == ".." ]; then
            __PPPP__path="${__posh__stacktrace##*:}/.."
        elif [ "$__PPPP__path" == "." ]; then
            __PPPP__path="${__posh__stacktrace##*:}"
        fi
    fi
    if [ -n "${!__PPPP__varname}" ]; then
        eval "$__PPPP__varname"=\""$__PPPP__path:${!__PPPP__varname}"\"
    else
        eval "$__PPPP__varname"=\""$__PPPP__path"\"
    fi
}

use() {
    __posh__descend . "$1"
}

use-from() {
    __posh__prependpath USEPATH "$1"
}
