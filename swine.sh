# shellcheck disable=SC2148
################################################################################
# Make bash a little bit more like perl. Turn on strict error handling, and
# implement some of the more useful perl native functions.
# See: https://perldoc.perl.org/5.32.0/index-functions.html
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

set -o errexit
set -o pipefail
set -o nounset
__posh__err_report() {
    echo "errexit $? on line $(caller)" >&2
}
trap __posh__err_report ERR

# The default behaviour of `echo` differs between shells, so we deprecate it.
# say (from perl6/raku) forces there to be no escape-char handling at runtime.
# If we want to interpret escape sequences in literals then we should use $''.
# If we want to interpret them at runtime we should explicitly use $(echo -e).

say() {
    local text="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to say() at line $(caller)"
    fi
    printf '%s\n' "$text"
}

# warn() is the same as perl

warn() {
    local text="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to warn() at line $(caller)"
    fi
    printf '%s\n' "$text" >&2
}

# die() takes two arguments, unlike perl
# do something || die $errnum "$notice"

die() {
    local errcode="$1"; shift
    local text="$1"; shift
    if [ "$*" != "" ]; then
        die 102 "Too many arguments to die() at line $(caller)"
    fi
    printf '%s\n' "$text" >&2
    exit "$errcode"
}

# A simple reimplementation of try/catch using one global variable.
# try danger; if catch err && [[ err == 5 ]]; then ...

__posh__try_last_err=0

try() {
    __posh__try_last_err=0
    eval "$(printf " %s" "$@")" || __posh__try_last_err=$?
}

catch() {
    eval "$1"="$__posh__try_last_err"
    [ "$__posh__try_last_err" != 0 ]
}

# Find if the first argument is contained in the rest of the arguments.
# This is particularly useful for bash pseudo-arrays:
# if contains "$element" "${array[@]}"; then ...

contains() {
    local i element="$1"; shift
    for i; do
        if [ "$i" == "$element" ]; then
            return 0
        fi
    done
    return 1
}
