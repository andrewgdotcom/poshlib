# shellcheck disable=SC2148
################################################################################
# Avoid the overhead of calling out to `sed` or `tr` wherever possible
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

tr.mapchar() {
    local old=$1
    local new=$2
    local char=
    local IFS=
    while read -d '' -rn1 char; do
        chopold="${old%%"$char"*}"
        if [[ "$chopold" != "${old}" ]]; then
            # find the corresponding character in the new set
            # by truncating them both one character at a time
            local newchar=${new:0:1}
            local chopnew=${new#?}
            while [[ $chopold ]]; do
                newchar=${chopnew:0:1}
                chopnew=${chopnew#?}
                chopold=${chopold#?}
            done
            [[ "$newchar" == $'\0' ]] || printf '%c' "$newchar"
        else
            printf '%c' "$char"
        fi
    done
}

tr.strip() {
    local buffer=
    local discarding=1
    local char=
    local whitespace=${IFS:-$' \t\n'}
    local IFS=

    # Strip leading whitespace by starting up in a discarding state and
    # only leave it when we encounter the first non-whitespace char.
    # Strip trailing whitespace by buffering any contiguous whitespace and
    # flush it only if/when we find the next non-whitespace char.

    while read -d '' -rn1 char; do
        if [[ "${whitespace%"$char"*}" != "${whitespace}" ]]; then
            # buffer, unless we are in initial discarding mode
            [[ $discarding ]] || buffer+=$char
        else
            # flush and reset state
            printf '%s%c' "$buffer" "$char"
            buffer=
            discarding=
        fi
    done
}

if
    ( __tr_i=A; echo ${__tr_i,}; echo ${__tr_i//A/B} ) >/dev/null 2>&1
then
    tr.lowercase() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\${$fromvar,,}"
    }
    tr.UPPERCASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\${$fromvar^^}"
    }
    tr.snake_case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "__tr_temp=\${$fromvar//-/_}; $tovar=\${__tr_temp,,}"
    }
    tr.UPPER_SNAKE_CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "__tr_temp=\${$fromvar//-/_}; $tovar=\${__tr_temp^^}"
    }
    tr.kebab-case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "__tr_temp=\${$fromvar//_/-}; $tovar=\${__tr_temp,,}"
    }
    tr.UPPER-KEBAB-CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "__tr_temp=\${$fromvar//_/-}; $tovar=\${__tr_temp^^}"
    }
else
    tr.lowercase() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz <<<\"\$$fromvar\")"
    }
    tr.UPPERCASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ <<<\"\$$fromvar\")"
    }
    tr.snake_case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar ABCDEFGHIJKLMNOPQRSTUVWXYZ- abcdefghijklmnopqrstuvwxyz_ <<<\"\$$fromvar\")"
    }
    tr.UPPER_SNAKE_CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar abcdefghijklmnopqrstuvwxyz- ABCDEFGHIJKLMNOPQRSTUVWXYZ_ <<<\"\$$fromvar\")"
    }
    tr.kebab-case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar ABCDEFGHIJKLMNOPQRSTUVWXYZ_ abcdefghijklmnopqrstuvwxyz- <<<\"\$$fromvar\")"
    }
    tr.UPPER-KEBAB-CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr.mapchar abcdefghijklmnopqrstuvwxyz_ ABCDEFGHIJKLMNOPQRSTUVWXYZ- <<<\"\$$fromvar\")"
    }
fi
