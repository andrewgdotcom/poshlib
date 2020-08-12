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
if [ "${__posh__stacktrace:-}" == "" ]; then
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

    # Always clobber __posh__usepath to prevent shenanigans.
    __posh__usepath=
    # IFF we are using bash, we can initialise __posh__usepath automagically
    # with bashisms. Otherwise, we must invoke `use-from` in the calling script.
    # TODO: support other shells
    if [ "$__posh__detected__shell" == "bash" ]; then
        __posh__usepath=$(dirname $(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}"))
        [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: INIT usepath=$__posh__usepath" >&2
        # Initialize a stacktrace
        __posh__stacktrace="$(readlink "${BASH_SOURCE[1]}" || echo "${BASH_SOURCE[1]}")"
        [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: INIT stacktrace=$__posh__stacktrace" >&2
    else
        __posh__usepath=""
        __posh__stacktrace="__UNKNOWN__"
    fi
fi

__posh__descend() {
    local action="$1"; shift
    local module="$1"; shift
    local dir
    local IFS=:
    if [ "$action" != "." ]; then
        path_variable=__posh__${action}__path
        trace_variable=__posh__${action}__trace
    elif [ -n "${__posh__usepath:-}" ]; then
        path_variable="__posh__usepath"
        trace_variable="__posh__stacktrace"
    else
        echo "# POSH_ERROR: unexpected descent before init" >&2
        exit 101
    fi
    for dir in ${!path_variable}; do
        if [ -f "$dir/$module.sh" ]; then
            local trace="${!trace_variable}"
            local safe_module=$(echo "$dir/$module.sh" | tr : _)
            # prevent loops
            [ "${trace%:$safe_module}" == "$trace" ] || return 0
            [ "${trace%:$safe_module:*}" == "$trace" ] || return 0
            trace="${trace}:$safe_module"
            eval "$trace_variable"="$trace" # NASTY
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: $trace_variable=$trace" >&2
            "$action" "$dir/$module.sh"
            trace="${trace%:*}"
            eval "$trace_variable"="$trace" # NASTY
            [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: $trace_variable=$trace" >&2
            return 0
        fi
    done
    echo "# POSH_ERROR: Could not find ${module}.sh in $path_variable=${!path_variable}" >&2
    exit 101
}

__posh__prependpath() {
    local pathlist="$1"; shift
    local newpath="$1"; shift
    local trace="$1"; shift
    # make paths relative to script location, not PWD
    if [ "$__posh__detected__shell" == "bash" ]; then
        stacktop_dir=$(dirname ${trace##*:})
        if [ "$path" == "." ]; then
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
    __posh__descend . "$1"
}

use-from() {
    __posh__usepath=$(__posh__prependpath "${__posh__usepath:-}" "$1" "$__posh__stacktrace")
}
