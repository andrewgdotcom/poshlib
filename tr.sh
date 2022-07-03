# shellcheck disable=SC2148
################################################################################
# Avoid the overhead of calling out to `sed` or `tr` wherever possible
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

if
    ( __tr_i=A; echo ${__tr_i,}; echo ${__tr_i//A/B} ) >/dev/null 2>&1
then
    __tr_implementation=native
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
    __tr_implementation=external
    tr.snake_case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr A-Z- a-z_ <<<\"\$$fromvar\")"
    }
    tr.UPPER_SNAKE_CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr a-z- A-Z_ <<<\"\$$fromvar\")"
    }
    tr.kebab-case() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr A-Z_ a-z- <<<\"\$$fromvar\")"
    }
    tr.UPPER-KEBAB-CASE() {
        fromvar=$1
        tovar="${2:-"$1"}"
        eval "$tovar=\$(tr a-z_ A-Z- <<<\"\$$fromvar\")"
    }
fi

tr.mapchar() {
    local old=$1
    local new=$2
    local char=
    local IFS=
    while read -d '' -rn1 char; do
        if [[ $char == "$old" ]]; then
            printf '%c' "$new"
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
