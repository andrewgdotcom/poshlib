# shellcheck disable=SC2148
################################################################################
# Extended getopt handler based on https://stackoverflow.com/a/29754866/1485960
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

###############################
# SIMPLE METHODS (RECOMMENDED)
###############################
#
# Parameters are supplied on the command line as gnu long options:
#
#    command --parameter=value
#
# If a value is given, the value of the long option `parameter` will be provided
# to the calling environment in a variable `PARAMETER`. Otherwise, the variable 
# will be ignored (this allows the caller to easily fall back to an envar).
#
# Flags take a similar format:
#
#    command --debug
#    command --no-debug
#
# If the flag is provided, the corresponding variable is set to "true".
# If the inverse "no-flag" is provided, the variable is set to "false".
# If neither is provided, the variable is ignored.
#
# Valid parameters and flags are defined by the calling script, e.g.:
#
# --
#   use parse-opt
#
#   parse-opt.prefix COMMAND_
#   parse-opt.params OUTPUT
#   parse-opt.flags VERBOSE FORCE
#
#   eval "$(parse-opt-simple)"
# --
#
# `parse-opt.params` takes a list of with-value long options.
# `parse-opt.flags` takes a list of no-value options.
# `parse-opt.prefix` takes a prefix that will be applead to each variable name.
#
# `parse-opt-simple` outputs a list of commands that MUST be `eval`ed in the
# calling environment, as they manipulate $@.
#
# Variable names will be coerced to UPPER_SNAKE_CASE, while command line option
# names will be coerced to kebab-case and prefixed with `--`.
#
# No default values can be supplied when using simple mode; to set default values
# you should do so in the shell after invoking parse-opt, e.g.:
#
#   : "${VARIABLE="default value"}"
#
# (DEPRECATED METHOD)
#
# Alternatively, the global variables PO_SIMPLE_PREFIX, PO_SIMPLE_FLAGS and
# PO_SIMPLE_PARAMS can be defined directly, e.g.:
#
# --
#   use parse-opt
#
#   PO_SIMPLE_PREFIX="COMMAND_"
#   PO_SIMPLE_PARAMS="OUTPUT"
#   PO_SIMPLE_FLAGS="VERBOSE FORCE"
#
#   eval "$(parse-opt-simple)"
# --
#
# This functionality may be removed in a future version of parse-opt.

####################
# LOW LEVEL METHODS
####################
#
# We can achieve more granular control over getopt using low level methods.
#
# Short and long option definitions must be populated in the calling script:
#
#   parse-opt.short KEY VALUE
#   parse-opt.long KEY VALUE
#
# Example:
#
# --
#   use parse-opt
#   parse-opt.init
#
#   parse-opt.short d:: DEBUG=1
#   parse-opt.short v VERBOSE
#   parse-opt.short f FORCE
#
#   parse-opt.long output: OUTPUT
#   parse-opt.long comment:: COMMENT="no comment"
#   parse-opt.long verbose VERBOSE
#
#   eval "$(parse-opt)"
# --
#
# `parse-opt.init` resets the internal state of the parser. This MUST always
# be invoked first, as parser state will be inherited from the calling scope.
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

###############################################################################

# Fakehash is required in the calling context because evaluation is done there
use fakehash

parse-opt.short() { fakehash.update PO_SHORT_MAP "$1" "$2"; }
parse-opt.long() { fakehash.update PO_LONG_MAP "$1" "$2"; }
parse-opt.prefix() { PO_SIMPLE_PREFIX="$1"; }
parse-opt.params() { local IFS; IFS=$' \t\n'; PO_SIMPLE_PARAMS="$*"; }
parse-opt.flags() { local IFS; IFS=$' \t\n'; PO_SIMPLE_FLAGS="$*"; }

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "FATAL: Enhanced getopt not found!" >&2
    exit 1
fi

__parse_opt.set_var() {
    local var_with_default="$1"
    local value="$2"
    # split on `=` into variable and default value.
    # NB we do it the hard way to ensure default="" if no default given.
    local variable="${var_with_default%=*}"
    local default="${var_with_default#"${variable}"}"
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

__parse_opt.canonicalize_argv() {
    local key
    local value
    local shortkeys
    local longkeys
    fakehash.keys.read-a shortkeys PO_SHORT_MAP
    fakehash.keys.read-a longkeys PO_LONG_MAP

    for key in ${shortkeys+"${shortkeys[@]}"}; do
        value="$(fakehash.get PO_SHORT_MAP "$key")"
        if [[ "${value%=*}" != "${value}" && \
            "${key%::}" == "${key}" ]]; then
            # sanity failure!
            echo "PANIC: non-optional key '$key' must not have a default value" >&2
            exit 4
        fi
    done

    declare -a inverses
    for key in ${longkeys+"${longkeys[@]}"}; do
        value="$(fakehash.get PO_LONG_MAP "$key")"
        if [[ "${value%=*}" != "${value}" && \
            "${key%::}" == "${key}" ]]; then
            # sanity failure!
            echo "PANIC: non-optional key '$key' must not have a default value" >&2
            exit 4
        fi
        if [[ "$key" == "${key%:}" ]]; then
            # key takes no value, therefore we can support no-<key>
            inverses+=( "no-$key" )
        fi
    done

    # concatenate option hash keys and invoke enhanced getopt on ARGV
    local canonical_args
    ! canonical_args=$(getopt \
        -o "${shortkeys+"${shortkeys[*]}"}" \
        -l "${longkeys+"${longkeys[*]}"} ${inverses+"${inverses[*]}"}" \
        --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 2
    fi
    # `set` reloads ARGV; `--` forbids `set` from consuming options
    echo set -- "$canonical_args"
}

__parse_opt.parse_argv() {
    local key
    local keys
    local opt
    local variable
    while true; do
        if [[ "${1:-}" == "--" ]]; then
            # stop processing options
            shift
            break
        fi
        fakehash.keys.read-a keys PO_SHORT_MAP
        for key in ${keys+"${keys[@]}"}; do
            # strip trailing colon(s) if possible
            # we can test opt==key below to see if the option expects a value
            opt="${key%%:*}"
            variable="$(fakehash.get PO_SHORT_MAP "$key")"
            if [[ "${1:-}" == "-$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __parse_opt.set_var "${variable}" "true"
                    shift
                    continue 2
                else
                    __parse_opt.set_var "${variable}" "$2"
                    shift 2
                    continue 2
                fi
            fi
        done
        fakehash.keys.read-a keys PO_LONG_MAP
        for key in ${keys+"${keys[@]}"}; do
            # strip trailing colon(s) if possible
            # we can test opt==key below to see if the option expects a value
            opt="${key%%:*}"
            variable="$(fakehash.get PO_LONG_MAP "$key")"
            if [[ "${1:-}" == "--$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __parse_opt.set_var "${variable}" "true"
                    shift
                    continue 2
                else
                    __parse_opt.set_var "${variable}" "$2"
                    shift 2
                    continue 2
                fi
            elif [[ "${1:-}" == "--no-$opt" ]]; then
                if [[ "$opt" == "$key" ]]; then
                    __parse_opt.set_var "${variable}" "false"
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
    echo "set -- $(printf ' %q' "$@")"
}

parse-opt-init() {
    # old school, to be called via eval
    echo "WARNING: 'eval \$(parse-opt-init)' is deprecated, use 'parse-opt.init' instead" >&2
    echo fakehash.declare PO_LONG_MAP
    echo fakehash.declare PO_SHORT_MAP
}
parse-opt.init() {
    fakehash.declare PO_LONG_MAP
    fakehash.declare PO_SHORT_MAP
}

parse-opt() {
    # shellcheck disable=SC2016
    echo 'eval "$(__parse_opt.canonicalize_argv "$@")"'
    # shellcheck disable=SC2016
    echo 'eval "$(__parse_opt.parse_argv "$@")"'
}

parse-opt-simple() {
    # This is normally called from within a command substitution, so we can `use` safely
    use tr

    # Split PO_SIMPLE_* on default whitespace
    local IFS=$' \t\n'
    local i param variable

    echo parse-opt.init

    # Coerce prefix to UPPER_SNAKE_CASE
    : "${PO_SIMPLE_PREFIX:=}"
    tr.UPPER_SNAKE_CASE PO_SIMPLE_PREFIX
    # Coerce argument names to lower-kebab-case and the corresponding envars to UPPER_SNAKE_CASE
    # shellcheck disable=SC2034
    for i in ${PO_SIMPLE_PARAMS:-}; do
        tr.UPPER_SNAKE_CASE i variable
        tr.kebab-case i param
        # This has to be run in the calling context, otherwise our changes will be descoped
        echo parse-opt.long "$param:" "${PO_SIMPLE_PREFIX}${variable}"
    done
    # and for flags
    # shellcheck disable=SC2034
    for i in ${PO_SIMPLE_FLAGS:-}; do
        tr.UPPER_SNAKE_CASE i variable
        tr.kebab-case i param
        # This has to be run in the calling context, otherwise our changes will be descoped
        echo parse-opt.long "$param" "${PO_SIMPLE_PREFIX}${variable}"
    done
    parse-opt
}
