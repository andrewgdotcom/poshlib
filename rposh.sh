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
    PO_SIMPLE_FLAGS="SUDO"
    PO_SIMPLE_PARAMS="SUDO_USER SSH_OPTIONS SSH_KEEPALIVE"
    eval $(parse-opt-simple)

    target="$1"; shift
    command="$1"; shift

    tmpdir=$(mktemp -d)
    flatten "$command" > $tmpdir/command
    chmod +x $tmpdir/command

    # sanitise arguments
    args=()
    for i in "$@"; do
        args=(${args[@]} $(printf %q $i))
    done

    RPOSH_SSH_OPTIONS=("${RPOSH_SSH_OPTIONS[@]}" "-o" "ControlPath=${tmpdir}/${target}")
    [ -n "${RPOSH_SSH_KEEPALIVE:-}" ] || RPOSH_SSH_KEEPALIVE=60

    # start up a controlmaster connection and background it
    ssh -f "-o" ControlMaster=true "${RPOSH_SSH_OPTIONS[@]}" -- \
        "$target" "sleep $RPOSH_SSH_KEEPALIVE" &

    remote_tmpdir=$(ssh "${RPOSH_SSH_OPTIONS[@]}" -- \
        "$target" "mktemp -d" < /dev/null)
    scp -q -p "${RPOSH_SSH_OPTIONS[@]}" -- \
        "$tmpdir/command" "${target}:${remote_tmpdir}/command"
    ssh "${RPOSH_SSH_OPTIONS[@]}" -- \
        "$target" "$remote_tmpdir/command" "${args[@]}"

    # shut down controlmaster connection
    ssh "${RPOSH_SSH_OPTIONS[@]}" -O exit -- "$target" 2> /dev/null
) }
