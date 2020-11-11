################################################################################
# Extended getopt handler based on https://stackoverflow.com/a/29754866/1485960
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
#
# NB this script uses the __PO__ prefix on internal functions and variables
# to avoid naming clash. DO NOT USE __PO__<*> anywhere in the calling script.
################################################################################

#############
# SIMPLE USAGE
#############
#
# PO_SIMPLE_PREFIX, PO_SIMPLE_FLAGS and PO_SIMPLE_PARAMS must be defined in the
# calling script, e.g.:
#
# --
# use parse-opt
#
# PO_SIMPLE_PREFIX="COMMAND"
# PO_SIMPLE_PARAMS="OUTPUT"
# PO_SIMPLE_FLAGS="VERBOSE FORCE"
#
# eval $(parse-opt-simple)
# --
#
# PO_SIMPLE_PARAMS contains a list of names of with-value long options (minus
# leading --), and PO_SIMPLE_FLAGS contains a list of names of no-value options.
# Envar names will be coerced to uppercase and prefixed by PO_SIMPLE_PREFIX.
# Option names will be coerced to lowercase. No default values can be supplied.

#############
# FULL USAGE
#############
#
# PO_SHORT_MAP and PO_LONG_MAP must be populated in the calling script, e.g.:
#
# --
# use parse-opt
# eval $(parse-opt-init)
#
# PO_SHORT_MAP["d::"]="DEBUG=1"
# PO_SHORT_MAP["v"]="VERBOSE"
# PO_SHORT_MAP["f"]="FORCE"
#
# PO_LONG_MAP["output:"]="OUTPUT"
# PO_LONG_MAP["comment::"]="COMMENT=no comment"
# PO_LONG_MAP["verbose"]="VERBOSE"
#
# eval $(parse-opt)
# --
#
# A single colon in the key indicates that the command-line option requires a
# value, and a double colon that a value is optional; otherwise the option
# takes no value. This is a similar syntax to that of extended getopt, except
# that each command-line option is treated individually.
#
# The map values are the names of the shell variables to which the command-line
# values will be assigned. If the map value contains an assignment, it defines
# the default value of the variable when the command line option is provided
# with no value. Default values must only be used with double-colon keys.
# NB the default value does not require the use of embedded quote characters.
#
# If a no-value option is supplied, the corresponding variable is set to
# "true". A no-value long option "<OPTION>" implies the existence of a no-value
# inverse long option of the form "--no-<OPTION>", which sets the corresponding
# variable to "false".

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "Enhanced getopt not found!" >&2
    exit 1
fi

__PO__set_var() {
    local var_with_default="$1"
    local value="$2"
    # split on `=` into variable and default value.
    # NB we do it the hard way to ensure default="" if no default given.
    local variable="${var_with_default%=*}"
    local default="${var_with_default#${variable}}"
    default="${default#=}"
    # if we have been passed a value, set the variable to it,
    # otherwise to the default (if that was provided)
    # NB the embedded quotes prevent eval from word-splitting the values
    if [[ $value ]]; then
        echo "$variable='$value';"
    elif [[ $default ]]; then
        echo "$variable='$default';"
    fi
}

__PO__canonicalize_argv() {
    local key
    for key in "${!PO_SHORT_MAP[@]}"; do
        if [[ "${PO_SHORT_MAP[$key]%=*}" != "${PO_SHORT_MAP[$key]}" && \
            "${key%::}" == "${key}" ]]; then
            # sanity failure!
            echo "PANIC: non-optional key '$key' must not have a default value" >&2
            exit 4
        fi
    done

    declare -A inverses
    for key in "${!PO_LONG_MAP[@]}"; do
        if [[ "${PO_LONG_MAP[$key]%=*}" != "${PO_LONG_MAP[$key]}" && \
            "${key%::}" == "${key}" ]]; then
            # sanity failure!
            echo "PANIC: non-optional key '$key' must not have a default value" >&2
            exit 4
        fi
        if [[ "$key" == "${key%:}" ]]; then
            # key takes no value, therefore we can support no-<key>
            inverses["no-$key"]="${PO_LONG_MAP[$key]}"
        fi
    done

    # concatenate option hash keys and invoke enhanced getopt on ARGV
    local canonical_args
    ! canonical_args=$(getopt \
        -o "$(IFS="";echo "${!PO_SHORT_MAP[*]}")" \
        -l "$(IFS=,;echo "${!PO_LONG_MAP[*]}","${!inverses[*]}")" \
        --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 2
    fi

    # `set` reloads ARGV; `--` forbids set from consuming options
    echo set -- "$canonical_args"
}

__PO__parse_argv() {
    local key
    local opt
    local variable
    while true; do
        if [[ "${1:-}" == "--" ]]; then
            # stop processing options
            shift
            break
        fi
        for key in "${!PO_SHORT_MAP[@]}"; do
            # strip trailing colon(s) if possible
            # we can test opt==key below to see if the option expects a value
            opt="${key%%:*}"
            variable="${PO_SHORT_MAP[$key]}"
            if [[ "${1:-}" == "-$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __PO__set_var "${variable}" "true"
                    shift
                    continue 2
                else
                    __PO__set_var "${variable}" "$2"
                    shift 2
                    continue 2
                fi
            fi
        done
        for key in "${!PO_LONG_MAP[@]}"; do
            # strip trailing colon(s) if possible
            # we can test opt==key below to see if the option expects a value
            opt="${key%%:*}"
            variable="${PO_LONG_MAP[$key]}"
            if [[ "${1:-}" == "--$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __PO__set_var "${variable}" "true"
                    shift
                    continue 2
                else
                    __PO__set_var "${variable}" "$2"
                    shift 2
                    continue 2
                fi
            elif [[ "${1:-}" == "--no-$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __PO__set_var "${variable}" "false"
                    shift
                    continue 2
                else
                    echo "PANIC when parsing options, aborting" >&2
                    exit 3
                fi
            fi
        done
        echo "PANIC when parsing options, aborting" >&2
        exit 3
    done

    # return the remaining arguments
    # `set` reloads ARGV; `--` forbids set from consuming options
    # `printf %q` re-quotes the arguments to prevent word-splitting
    # shellcheck disable=SC2046
    echo set -- $(printf ' %q' "$@")
}

parse-opt-init() {
    echo 'declare -A PO_SHORT_MAP; declare -A PO_LONG_MAP;'
}

parse-opt() {
    # shellcheck disable=SC2016
    echo 'eval $(__PO__canonicalize_argv "$@");'
    # shellcheck disable=SC2016
    echo 'eval $(__PO__parse_argv "$@");'
}

parse-opt-simple() {
    # Reduce boilerplate even further
    parse-opt-init

    # Split on default whitespace
    local IFS=$' \t\n'
    # Coerce prefix to upper case
    PO_SIMPLE_PREFIX="$(tr a-z- A-Z_ <<< "${PO_SIMPLE_PREFIX:-}")"
    # Coerce argument names to lower case and the corresponding envars to upper case
    for i in ${PO_SIMPLE_PARAMS:-}; do
        echo "PO_LONG_MAP[$(tr A-Z_ a-z- <<< "$i"):]=${PO_SIMPLE_PREFIX}$(tr a-z- A-Z_ <<< "$i");"
    done
    # and for flags
    for i in ${PO_SIMPLE_FLAGS:-}; do
        echo "PO_LONG_MAP[$(tr A-Z_ a-z- <<< "$i")]=${PO_SIMPLE_PREFIX}$(tr a-z- A-Z_ <<< "$i");"
    done

    parse-opt
}
