# shellcheck disable=SC2148
################################################################################
# Initialise poshlib. Define the `use` command and reset settings to default.
# All other features are optional and can be imported using `use`.
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
#
# . /path/to/poshlib/poshlib.sh || exit 1
################################################################################

# Avoid reinitialization
if [ "${__posh__callstack:-}" == "" ]; then
    # Shell detector stolen from https://www.av8n.com/computer/shell-dialect-detect
    __posh__detected__shell=$( (
        # shellcheck disable=SC2034,SC2030
        res1=$(export PATH=/dev/null/$$
          type -p 2>/dev/null)
        st1="$?"

        # shellcheck disable=SC2031
        res2=$(export PATH=/dev/null/$$
          type declare 2>/dev/null)
        # shellcheck disable=SC2034
        st2="$?"        # not

        # this version works without sed, and indeed without a $PATH
        penult='nil'  ult=''
        # shellcheck disable=SC2116,SC2086
        for word in $(echo $res2) ; do
          penult="$ult"
          ult="$word"
        done

        tag="${st1}.${penult}_${ult}"
        if   [ "${tag}" == 0.shell_builtin ]; then echo bash  ; exit
        elif [ "${tag}" == 1.shell_builtin ]; then echo bash3 ; exit
        elif [ "${tag}" ==   127.not_found ]; then echo dash  ; exit
        elif [ "${tag}" ==          2.nil_ ]; then echo ksh93 ; exit
        elif [ "${tag}" == 1.reserved_word ]; then echo zsh5  ; exit
        else echo "unknown shell"
        fi
    ) )
    [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: detected shell=$__posh__detected__shell" >&2

    # Always clobber __posh__usepath to prevent shenanigans.
    __posh__usepath=
    # IFF we are using bash, we can initialise __posh__usepath automagically
    # with bashisms. Otherwise, we must invoke `use-from` in the calling script.
    # TODO: support other shells
    if [ "$__posh__detected__shell" == "unknown shell" ]; then
        echo "Unknown shell; aborting" >&2
        exit 101
    elif [ "$__posh__detected__shell" == "bash" ] || [ "$__posh__detected__shell" == "bash3" ]; then
        __posh__usepath=$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")
        [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: INIT usepath=$__posh__usepath" >&2
        # Initialize a callstack
        __posh__callstack="$(readlink "${BASH_SOURCE[1]}" || echo "${BASH_SOURCE[1]}")"
        [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: INIT callstack=$__posh__callstack" >&2
    else
        __posh__usepath=""
        __posh__callstack="__UNKNOWN__"
    fi
fi

__posh__descend() {
    local action="$1"; shift
    local module="$1"; shift
    local dir=
    local path_variable="__posh__usepath"
    local stack_variable="__posh__callstack"
    local IFS=:
    if [ "$action" != "." ]; then
        path_variable=__posh__${action}__path
        stack_variable=__posh__${action}__stack
    fi
    if [ -z "${!path_variable:-}" ]; then
        echo "# POSH_ERROR: unexpected descent before init" >&2
        exit 101
    fi
    for dir in ${!path_variable}; do
        if [ -f "$dir/$module.sh" ]; then
            local stack="${!stack_variable}"
            local safe_module
            safe_module=$(echo "$dir/$module.sh" | tr : _)
            # prevent loops
            [ "${stack#$safe_module:}" == "$stack" ] || return 0
            [ "${stack#*:$safe_module:}" == "$stack" ] || return 0
            stack="$safe_module:$stack"
            eval "$stack_variable=\"$stack\"" # NASTY
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: $stack_variable=$stack" >&2
            "$action" "$dir/$module.sh"
            stack="${stack#*:}"
            eval "$stack_variable=\"$stack\"" # NASTY
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: $stack_variable=$stack" >&2
            return 0
        fi
    done
    echo "# POSH_ERROR: Could not find ${module}.sh in $path_variable=${!path_variable}" >&2
    exit 101
}

__posh__prependpath() {
    local pathlist="$1"; shift
    local newpath="$1"; shift
    local stack="$1"; shift
    # make paths relative to script location, not PWD
    if [ "$__posh__detected__shell" == "bash" ] || [ "$__posh__detected__shell" == "bash3" ]; then
        stacktop_dir=$(dirname "${stack%%:*}")
        if [ "$newpath" == "." ]; then
            newpath="$stacktop_dir"
        elif [ "${newpath#/}" == "$newpath" ]; then
            newpath="$stacktop_dir/${newpath#./}"
        fi
    fi
    if [ -n "$pathlist" ]; then
        echo -E "$newpath:$pathlist"
    else
        echo -E "$newpath"
    fi
}

use() {
    [ -z "${POSH_DEBUG:-}" ] || echo  "# USE $1" >&2
    __posh__descend . "$1"
    [ -z "${POSH_DEBUG:-}" ] || echo  "# END USE $1" >&2
}

use-from() {
    __posh__usepath=$(__posh__prependpath "${__posh__usepath:-}" "$1" "$__posh__callstack")
    [ -z "${POSH_DEBUG:-}" ] || echo  "# USE FROM $1 >> $__posh__usepath" >&2
}
