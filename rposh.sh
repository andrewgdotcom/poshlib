# shellcheck disable=SC2148
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
    use job-pool

    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: COMMAND: rscript $*"

    # shellcheck disable=SC2034
    PO_SIMPLE_PREFIX="RPOSH_"
    # shellcheck disable=SC2034
    PO_SIMPLE_PARAMS="SUDO_USER SSH_USER SSH_OPTIONS SSH_KEEPALIVE STDOUT_DIR STDERR_DIR THREADS"
    eval "$(parse-opt-simple)"

    host_list="$1"; shift
    command="$1"; shift
    base_command=$(basename "$command")

    # shellcheck disable=SC2034
    error_log=""

    ssh_options=("-o" "ControlPersist=${RPOSH_SSH_KEEPALIVE:-60}" \
        "-o" "ControlMaster=auto")

    # parse host_list into an array
    IFS=, read -r -a hosts <<< "$host_list"
    # parse RPOSH_SSH_OPTIONS into an array, and intersperse them with "-o" flags
    IFS=, read -r -a ssh_key_values <<< "${RPOSH_SSH_OPTIONS:-}"
    for option in "${ssh_key_values[@]}"; do
        ssh_options=("${ssh_options[@]}" "-o" "$option")
    done
    if [ -n "${RPOSH_SSH_USER:-}" ]; then
        ssh_options=("${ssh_options[@]}" "-o" "User=${RPOSH_SSH_USER}")
    fi
    if [ -n "${RPOSH_SUDO_USER:-}" ]; then
        pre_command=("sudo" "-u" "${RPOSH_SUDO_USER}" "--")
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: pre_command=(${pre_command[*]})"
    fi
    tmpdir=$(mktemp -d)
    flatten "$command" > "$tmpdir/$base_command"
    chmod +x "$tmpdir/$base_command"
    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: ssh_options=(${ssh_options[*]})"
    [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: hosts=(${hosts[*]})"

    invoke_remote() {
        local target=$1; shift
        local e
        local controldir controlpath stdout_dev stderr_dev remote_tmpdir

        if [ -n "${XDG_RUNTIME_DIR:-}" ]; then
            controldir="${XDG_RUNTIME_DIR}/rposh"
            # shellcheck disable=SC2174
            mkdir -m 0700 -p "$controldir"
        else
            controldir=$tmpdir
        fi
        controlpath="${controldir}/${target}"

        if
            [ -f "$controlpath" ] && \
            ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                -O check -- "$target" >/dev/null 2>&1 && \
            timeout 5 \
                ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                    -- "$target" "exit 0" >/dev/null 2>&1
        then
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: reusing control socket $controlpath"
        else
            # force kill any stale controlmaster connection
            ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                -O exit -- "$target" >/dev/null 2>&1 || true
            # start up a new controlmaster connection
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: opening control socket $controlpath"
            try ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                -- "$target" "exit 0" >/dev/null 2>&1
            if catch e; then
                # shellcheck disable=SC2154
                warn "Error $e establishing connection to $target"
                return
            fi
        fi

        # redirect stdout and stderr as required
        stdout_dev=/proc/self/fd/1
        stderr_dev=/proc/self/fd/2
        [ -z "${RPOSH_STDOUT_DIR:-}" ] || stdout_dev="$RPOSH_STDOUT_DIR/$target.stdout"
        [ -z "${RPOSH_STDERR_DIR:-}" ] || stderr_dev="$RPOSH_STDERR_DIR/$target.stderr"

        remote_tmpdir=$(ssh "${ssh_options[@]}" \
            "-o" "ControlPath=$controlpath" -- "$target" "mktemp -d" </dev/null)
        scp -q -p "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -- \
            "$tmpdir/$base_command" "${target}:${remote_tmpdir}/$base_command"
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: remote_command=${pre_command[*]} $remote_tmpdir/$base_command"
        # shellcheck disable=SC2046
        ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" -- \
            "$target" "${pre_command[@]}" "$remote_tmpdir/$base_command" \
            $(printf ' %q' "$@") >> "$stdout_dev" 2>> "$stderr_dev"
        [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: command complete"

        if [ -z "${RPOSH_SSH_KEEPALIVE:-}" ] || [ -z "${XDG_RUNTIME_DIR:-}" ]; then
            # shut down controlmaster connection
            try ssh "${ssh_options[@]}" "-o" "ControlPath=$controlpath" \
                -O exit -- "$target" >/dev/null 2>&1
            if catch e; then
                warn "Error $e shutting down connection to $target"
            fi
            [ -z "${POSH_DEBUG:-}" ] || warn "# POSH_DEBUG: RPOSH: shut down connection to $target"
        fi
    }

    # initialise threadpool
    job_pool_init "${RPOSH_THREADS:-1}" "${POSH_DEBUG:-}"

    for target in "${hosts[@]}"; do
        # skip empty array elements, these can be created by trailing commas
        [ -n "$target" ] || continue
        job_pool_run invoke_remote "$target" "$@"
    done

    # wait and clean up
    try job_pool_shutdown
    if catch e; then
        warn "Error $e shutting down threadpool"
    fi
    # shellcheck disable=SC2154
    exit "$job_pool_nerrors"
) }
