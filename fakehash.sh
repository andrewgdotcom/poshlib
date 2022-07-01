# shellcheck disable=SC2148
###############################################################################
# Shell functions to emulate an associative array in a shell that doesn't
# natively support it, e.g. Darwin's bash v3.2
#
# fakehash.declare HASH
# fakehash.get HASH key
# fakehash.update HASH key value [key2 value2 ...]
# fakehash.remove HASH key [key ...]
# fakehash.compact HASH
# fakehash.unset HASH
#
# The first argument to each function above is the name of the "hash" variable.
# They produce no output, apart from `fakehash.get` which writes to its STDOUT
#
# There are also two bulk-reading functions. 
#
# fakehash.read-a ARRAY HASH key [key2 ...]
# fakehash.keys.read-a ARRAY HASH
#
# These produce no output, but work by analogy with `read -a` - the first argument
# is the name of an array variable in which to put the selected items.
#
#   declare -a keys
#   fakehash.readkeys keys HASH
#   for i in "${keys[@]}"; do something; done
#
# Note that our algorithm does not like using sparse arrays as the back end
# storage medium; we therefore have a specific `fakehash.compact` function to
# recover space.
###############################################################################

fakehash.declare() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    eval "$keys_var=()" || return 2
    eval "$values_var=()" || return 2
}

fakehash.get() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    shift

    # Copy keys and values into temporary storage (is there a better way?)
    local keys
    local values
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    eval 'values=( ${'"$values_var"'+"${'"$values_var"'[@]}"} )' || return 2

    local i
    for i in "${!keys[@]}"; do
        if [[ "${keys[$i]}" == "$1" ]]; then
            printf '%s' "${values[$i]}"
            break
        fi
    done
}

__fakehash.read() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    shift

    # Copy keys and values into temporary storage (is there a better way?)
    local keys
    local values
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    eval 'values=( ${'"$values_var"'+"${'"$values_var"'[@]}"} )' || return 2

    local key
    for key in "$@"; do
        local i
        for i in "${!keys[@]}"; do
            if [[ "${keys[$i]}" == "$key" ]]; then
                printf ' %q' "${values[$i]}"
                break
            fi
        done
    done
}
fakehash.read-a() {
    arrayname=$1; shift
    eval "$arrayname=( $(__fakehash.read "$@") )"
}

fakehash.remove() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    shift

    # Copy keys and values into temporary storage (is there a better way?)
    # This DOES NOT play nice with sparse storage (see below)
    local keys
    local values
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    eval 'values=( ${'"$values_var"'+"${'"$values_var"'[@]}"} )' || return 2

    local key
    for key in "$@"; do
        local i
        # Make sure the key is non-empty
        [[ $key ]] || return 3
        for i in "${!keys[@]}"; do
            if [[ "${keys[$i]}" == "$key" ]]; then
                # Don't unset, as we don't want to create a sparse array
                # Instead set both key and value to the empty string
                eval "${keys_var}[$i]=''"
                eval "${values_var}[$i]=''"
                break
            fi
        done
    done
}

fakehash.update() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    shift

    # Copy keys into temporary storage (is there a better way?)
    local keys
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2

    local i
    while [[ "${2+set}" == set ]]; do
        local found=
        local empty=
        # Make sure the key is non-empty
        [[ $1 ]] || return 3
        for i in "${!keys[@]}"; do
            if [[ "${keys[$i]}" == "$1" ]]; then
                # Overwrite the existing value
                eval "${values_var}[$i]=$(printf '%q' "$2")"
                found=true
                break
            elif [[ ! "${keys[$i]}" && ! $empty ]]; then
                # This is the first empty slot; keep note for later
                empty=$i
            fi
        done
        if [[ ! $found ]]; then
            # We didn't find the key in the array
            if [[ $empty ]]; then
                # Fill up an empty slot
                eval "$keys_var[$empty]=$(printf '%q' "$1")" || return 2
                eval "$values_var[$empty]=$(printf '%q' "$2")" || return 2
                # Populate temporary keys so we don't use the same "empty" slot again
                eval "keys[$empty]=$(printf '%q' "$1")" || return 2
            else
                # No empty slots, so let's append instead
                eval "$keys_var+=( $(printf '%q' "$1") )" || return 2
                eval "$values_var+=( $(printf '%q' "$2") )" || return 2
            fi
        fi
        shift; shift
    done
}

fakehash.compact() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"

    local keys
    local values
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    eval 'values=( ${'"$values_var"'+"${'"$values_var"'[@]}"} )' || return 2

    # It's the future or bust
    eval "$keys_var=()"
    eval "$values_var=()"

    local i
    for i in "${!keys[@]}"; do
        if [[ "${keys[$i]}" ]]; then
            # There's still a valid key in this slot.
            eval "${keys_var}+=( $(printf ' %q' "${keys[$i]}") )"
            eval "${values_var}+=( $(printf ' %q' "${values[$i]}") )"
        fi
    done
}

__fakehash.keys.read() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local keys
    local first=true
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    local i
    for i in "${!keys[@]}"; do
        if [[ "${keys[$i]}" ]]; then
            # There's still a valid key in this slot.
            if [[ $first || ! $IFS ]]; then
                printf '%q' "${keys[$i]}"
                first=
            else
                # Use the first character of IFS as our output separator
                printf '%c%q' "${IFS:0:1}" "${keys[$i]}"
            fi
        fi
    done
}
fakehash.keys.read-a() {
    arrayname=$1; shift
    eval "$arrayname=( $(__fakehash.keys.read "$@") )"
}

fakehash.unset() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    eval "unset $keys_var" || return 2
    eval "unset $values_var" || return 2
}
