# shellcheck disable=SC2148
################################################################################
# Replace the system `wc` with internal functions
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

wc.words() {
    local count=0
    local words=()
    local IFS=$' \t'
    while read -ra words; do (( count+=${#words[@]} )); done
    (( count+=${#words[@]} )) # if read hits EOF, it may still have read some data
    echo "$count"
}

wc.lines() {
    local count=0
    local line=
    local IFS=
    # shellcheck disable=SC2034
    while read -r line; do (( ++count )); done
    echo "$count"
}

wc.chars() {
    local count=0
    local char=
    local IFS=
    # shellcheck disable=SC2034
    while read -rn1 char; do (( ++count )); done
    echo "$count"
}

wc.count() {
    local match=$1
    local count=0
    local char=
    local IFS=
    while read -d '' -rn1 char; do
        [[ "$char" != "$match" ]] || (( ++count ))
    done
    echo "$count"
}
