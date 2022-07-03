# shellcheck disable=SC2148
################################################################################
# Avoid the overhead of calling out to `tr` if the shell has inbuilt support
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

if
    ( __tr_i=A; echo ${__tr_i,}; echo ${__tr_i//A/B} ) >/dev/null 2>&1
then
    __tr_implementation=native
    tr.snake_case() {
        eval "$1=\${$1//-/_}; $1=\${$1,,}"
    }
    tr.UPPER_SNAKE_CASE() {
        eval "$1=\${$1//-/_}; $1=\${$1^^}"
    }
    tr.kebab-case() {
        eval "$1=\${$1//_/-}; $1=\${$1,,}"
    }
    tr.UPPER-KEBAB-CASE() {
        eval "$1=\${$1//_/-}; $1=\${$1^^}"
    }
else
    __tr_implementation=external
    tr.snake_case() {
        eval "$1=\$(tr A-Z- a-z_ <<<\"\$$1\")"
    }
    tr.UPPER_SNAKE_CASE() {
        eval "$1=\$(tr a-z- A-Z_ <<<\"\$$1\")"
    }
    tr.kebab-case() {
        eval "$1=\$(tr A-Z_ a-z- <<<\"\$$1\")"
    }
    tr.UPPER-KEBAB-CASE() {
        eval "$1=\$(tr a-z_ A-Z- <<<\"\$$1\")"
    }
fi

tr.mapchar() {
    local from=$1
    local to=$2
    local char=
    local IFS=
    while read -d '' -rn1 char; do
        if [[ $char == "$from" ]]; then
            printf '%c' "$to"
        else
            printf '%c' "$char"
        fi
    done
}
