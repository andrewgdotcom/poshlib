# shellcheck disable=SC2148
################################################################################
# Declare a main entrypoint to a script. This allows the script to be both used
# as a module and run directly, by invoking the main entrypoint on evaluation
# IFF the current file is at the top of the call stack.
#
# To use, all code other than initialisation (i.e. functions, global variables)
# MUST be contained within functions, and the main() function invoked at the
# bottom of the script thus:
#
#   main <entrypoint_function> <arg1> <arg2>...
#
# CAVEAT: this currently only works under bash
################################################################################

main() {
    [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: main ${*:-}" >&2
    # shellcheck disable=SC2154
    if [ "$__posh__detected__shell" == "bash" ]; then
        # We expect to be in the second level of the bash call stack.
        # If we are any deeper, then the calling code is not at the top.
        # If it is not at the top, then it MUST NOT invoke a main function.
        if [ -n "${BASH_SOURCE[2]}" ]; then
            return 0
        fi
    else
        echo "Shell not supported" >&2
        return 1
    fi
    [ -z "${POSH_DEBUG:-}" ] || echo "# POSH_DEBUG: at top, running main" >&2
    "$@"
}
