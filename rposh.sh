################################################################################
# Run poshlib code (with optional use dependencies) in a remote context.
# This replaces e.g. `ansible -m script`, which is incompatible with `use`.
#
# Poshlib routines sourced with `use` will automagically work, but any data or
# code sourced with `.` or `source` must already exist on the remote side.
#
# This requires a version of ssh that supports ControlMaster.
################################################################################

rscript() { (
    use swine
    use flatten
    use parse-opt

    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: COMMAND: rscript $*"

    PO_SIMPLE_PREFIX="RPOSH_"
    PO_SIMPLE_PARAMS="SUDO_USER SSH_USER SSH_OPTIONS SSH_KEEPALIVE STDOUT_DIR STDERR_DIR"
    eval $(parse-opt-simple)

    host_list="$1"; shift
    command="$1"; shift

    default_keepalive=60

    # parse host_list into an array
    # TODO: why doesn't `say $1 | IFS=, read ...` work?
    IFS=, read -r -a hosts <<< "$host_list"
    # parse RPOSH_SSH_OPTIONS into an array, and intersperse them with "-o" flags
    IFS=, read -r -a ssh_key_values <<< "${RPOSH_SSH_OPTIONS:-}"
    for option in "${ssh_key_values[@]}"; do
        ssh_options=("${ssh_options[@]}" "-o" "$(printf '%q' "$option")")
    done
    if [ -n "${RPOSH_SSH_USER:-}" ]; then
        ssh_options=("${ssh_options[@]}" "-o" "User=${RPOSH_SSH_USER}")
    fi
    if [ -n "${RPOSH_SUDO_USER:-}" ]; then
        pre_command=("sudo" "-u" "${RPOSH_SUDO_USER}")
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: pre_command=(${ssh_options[*]})"
    fi
    tmpdir=$(mktemp -d)
    flatten "$command" > $tmpdir/command
    chmod +x $tmpdir/command
    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: ssh_options=(${ssh_options[*]})"
    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: hosts=(${hosts[*]})"

    for target in "${hosts[@]}"; do
        # skip empty array elements, these can be created by trailing commas
        [ -n "$target" ] || continue
        if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
            controldir="${XDG_RUNTIME_DIR}/rposh"
            mkdir -m 0700 -p $controldir
        else
            controldir=$tmpdir
        fi
        controlpath="${controldir}/${target}"

        if [ ! -e "$controlpath" ]; then
            # start up a controlmaster connection and background it
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: opening control socket $controlpath"
            ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                -f "-o" ControlMaster=true -- \
                "$target" "sleep ${RPOSH_SSH_KEEPALIVE:-$default_keepalive}" >/dev/null 2>&1 &
        else
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: reusing control socket $controlpath"
        fi

        # redirect stdout and stderr as required
        stdout_dev=/proc/self/fd/1
        stderr_dev=/proc/self/fd/2
        [[ ! ${RPOSH_STDOUT_DIR:-} ]] || stdout_dev="$RPOSH_STDOUT_DIR/$target.stdout"
        [[ ! ${RPOSH_STDERR_DIR:-} ]] || stderr_dev="$RPOSH_STDERR_DIR/$target.stderr"

        remote_tmpdir=$(ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -- \
            "$target" "mktemp -d" < /dev/null)
        scp -q -p "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -- \
            "$tmpdir/command" "${target}:${remote_tmpdir}/command"
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: remote_command=${pre_command[*]} $remote_tmpdir/command"
        ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -- \
            "$target" "${pre_command[@]}" "$remote_tmpdir/command" $(printf ' %q' "$@") \
            >> "$stdout_dev" 2>> "$stderr_dev"
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: command complete"

        if [ -z "${RPOSH_SSH_KEEPALIVE:-}" -o -z "${XDG_RUNTIME_DIR:-}" ]; then
            # shut down controlmaster connection
            ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -O exit -- "$target" 2> /dev/null
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: shut down connection to $target"
        fi
    done
) }
