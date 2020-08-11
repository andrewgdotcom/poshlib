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

    PO_SIMPLE_PREFIX="RPOSH"
    PO_SIMPLE_PARAMS="SUDO_USER SSH_USER SSH_OPTIONS SSH_KEEPALIVE"
    eval $(parse-opt-simple)

    target="$1"; shift
    command="$1"; shift

    : ${RPOSH_SSH_KEEPALIVE:=60}
    # parse RPOSH_SSH_OPTIONS into an array
    say "${RPOSH_SSH_OPTIONS:-}" | read -r -a ssh_options
    if [ -n "${RPOSH_SSH_USER:-}" ]; then
        ssh_options=("${ssh_options[@]}" "-l" "${RPOSH_SSH_USER}")
    fi
    if [ -n "${RPOSH_SUDO_USER:-}" ]; then
        pre_command=("sudo" "-u" "${RPOSH_SUDO_USER}")
    fi
    tmpdir=$(mktemp -d)
    flatten "$command" > $tmpdir/command
    chmod +x $tmpdir/command
    ssh_options=("${ssh_options[@]}" "-o" "ControlPath=${tmpdir}/${target}")

    # start up a controlmaster connection and background it
    ssh -f "-o" ControlMaster=true "${ssh_options[@]}" -- \
        "$target" "sleep $RPOSH_SSH_KEEPALIVE" &

    remote_tmpdir=$(ssh "${ssh_options[@]}" -- \
        "$target" "mktemp -d" < /dev/null)
    scp -q -p "${ssh_options[@]}" -- \
        "$tmpdir/command" "${target}:${remote_tmpdir}/command"
    ssh "${ssh_options[@]}" -- \
        "$target" "${pre_command[@]}" "$remote_tmpdir/command" $(printf ' %q' "$@")

    # shut down controlmaster connection
    ssh "${ssh_options[@]}" -O exit -- "$target" 2> /dev/null
) }
