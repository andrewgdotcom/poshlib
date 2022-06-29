# shellcheck disable=SC2148
################################################################################
# Shell functions to emulate an associative array in a shell that doesn't
# natively support it, e.g. Darwin's bash v3.2
#
# fakehash.declare ARRAY
# fakehash.get ARRAY key [key ...]
# fakehash.update ARRAY key=value [key=value ...]
# fakehash.remove ARRAY key [key ...]
# fakehash.compact ARRAY
# fakehash.unset ARRAY
#
# The first argument to each function is the name of the associative array.
# The rest of the arguments are either a list of keys (for hash.get), or a list
# of `key=value` pairs [key1=value1 key2=value2 ...] (for hash.add).
#
# Note that our algorithm does not like using sparse arrays as the back end
# storage medium; we therefore have a specific `fakehash.compact` function to
# recover space.
################################################################################

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

    local key
    for key in "$@"; do
        local i
        for i in "${!keys[@]}"; do
            if [[ "${keys[$i]}" == "$key" ]]; then
                printf '%s' "${values[$i]}"
                break
            fi
        done
    done
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
        # Silently strip values; this allows us to be called directly below
        key="${key%%=*}"
        # Make sure the key is still non-empty
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
    fakehash.remove "$@"
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    shift
    local pair
    for pair in "$@"; do
        eval "$keys_var+=( '${pair%%=*}' )" || return 2
        eval "$values_var+=( '${pair#*=}' )" || return 2
        shift
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
            eval "${keys_var}+=(\"${keys[$i]}\")"
            eval "${values_var}+=(\"${values[$i]}\")"
        fi
    done
}

fakehash.keys() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local keys
    eval 'keys=( ${'"$keys_var"'+"${'"$keys_var"'[@]}"} )' || return 2
    local i
    for i in "${!keys[@]}"; do
        if [[ "${keys[$i]}" ]]; then
            # There's still a valid key in this slot.
            printf ' %q' "${keys[$i]}"
        fi
    done
}

fakehash.unset() {
    [[ $1 == "${1//[^a-zA-Z0-9_]/}" ]] || return 1
    local keys_var="__fakehash_${1}_keys"
    local values_var="__fakehash_${1}_values"
    eval "unset $keys_var" || return 2
    eval "unset $values_var" || return 2
}
