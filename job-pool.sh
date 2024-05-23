# shellcheck disable=SC2148
# Job pooling for bash shell scripts
# This script provides a job pooling functionality where you can keep up to n
# processes/functions running in parallel so that you don't saturate a system
# with concurrent processes.
#
# Got inspiration from http://stackoverflow.com/questions/6441509/how-to-write-a-process-pool-bash-shell
#
# Copyright (c) 2012 Vince Tse
# with changes by Geoff Clements (c) 2014
# and delinting by Andrew Gallagher (c) 2020-2022
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

################################################################################
# private variables
################################################################################

# end-of-jobs marker
_job_pool_end_of_jobs="JOBPOOL_END_OF_JOBS"

# temporary working space
_job_pool_dir=
_job_pool_job_queue=
_job_pool_result_log=

# number of parallel jobs allowed.  also used to determine if job_pool_init
# has been called when jobs are queued.
_job_pool_pool_size=-1

# toggle command echoing
_job_pool_echo_command=

################################################################################
# public variables
################################################################################

# cumulative number of non-zero exits
job_pool_nerrors=0

################################################################################
# private functions
################################################################################

# \brief some implementations of flock(1) take a number, others take a filename
# \param[in] action
# \param[in] fd
function _job_pool.flock()
{
    if ! flock "$1" "$2" 2>/dev/null ; then
        flock "$1" "/dev/fd/$2"
    fi
}

# \brief debug output
function _job_pool.echo()
{
    if [[ "${_job_pool_echo_command}" ]]; then
        printf "%s\n" "$*" >&2
    fi
}

# \brief cleans up
function _job_pool.cleanup()
{
    rm -rf "${_job_pool_dir}"
}

# \brief signal handler
function _job_pool.exit_handler()
{
    _job_pool.stop_workers
    _job_pool.cleanup
}

# \brief print the exit codes for each command
# \param[in] result_log  the file where the exit codes are written to
function _job_pool.print_result_log()
{
    # shellcheck disable=SC2034
    job_pool_nerrors=$(grep -c ^ERROR "${_job_pool_result_log}")
    sed -e 's/^ERROR//' < "${_job_pool_result_log}"
}

# \brief the worker function that is called when we fork off worker processes
# \param[in] id  the worker ID
# \param[in] job_queue  the fifo to read jobs from
# \param[in] result_log  the temporary log file to write exit codes to
function _job_pool.worker()
{
    local id=$1
    local job_queue=$2
    local result_log=$3
    local cmd=

    exec 7<> "${job_queue}"
    while [[ "${cmd}" != "${_job_pool_end_of_jobs}" && -e "${job_queue}" ]]; do
        # workers block on the exclusive lock to read the job queue
        _job_pool.flock --exclusive 7 || return 1
        IFS=$'\v' read -r -a cmd <"${job_queue}"
        _job_pool.flock --unlock 7
        # the worker should exit if it sees the end-of-job marker or run the
        # job otherwise and save its exit code to the result log.
        if [[ "${cmd[0]}" == "${_job_pool_end_of_jobs}" ]]; then
            # write it one more time for the next sibling so that everyone
            # will know we are exiting.
            echo "${_job_pool_end_of_jobs}" >&7
        else
            _job_pool.echo "### _job_pool_worker-${id}: ${cmd[0]}"
            # run the job
            { "${cmd[@]}" ; }
            # now check the exit code and prepend "ERROR" to the result log entry
            # which we will use to count errors and then strip out later.
            local result=$?
            local status=
            if [[ "${result}" != "0" ]]; then
                status=ERROR
            fi
            # now write the error to the log, making sure multiple processes
            # don't trample over each other.
            exec 8<> "${result_log}"
            _job_pool.flock --exclusive 8
            _job_pool.echo "${status}job_pool: exited ${result}: ${cmd[*]}" >> "${result_log}"
            _job_pool.flock --unlock 8
            exec 8>&-
            _job_pool.echo "### _job_pool_worker-${id}: exited ${result}: ${cmd[*]}"
        fi
    done
    exec 7>&-
}

# \brief sends message to worker processes to stop
function _job_pool.stop_workers()
{
    # send message to workers to exit, and wait for them to stop before
    # doing cleanup.
    printf "%s\\n" "${_job_pool_end_of_jobs}" >> "${_job_pool_job_queue}"
    wait
}

# \brief fork off the workers
# \param[in] job_queue  the fifo used to send jobs to the workers
# \param[in] result_log  the temporary log file to write exit codes to
function _job_pool.start_workers()
{
    local job_queue=$1
    local result_log=$2
    for ((i=0; i<"${_job_pool_pool_size}"; i++)); do
        _job_pool.worker "${i}" "${job_queue}" "${result_log}" &
    done
}

################################################################################
# public functions
################################################################################

# \brief initializes the job pool
# \param[in] pool_size  number of parallel jobs allowed
# \param[in] echo_command  1 to turn on echo, 0 to turn off
function job-pool.init()
{
    local pool_size=${1:-1}
    local echo_command=${2:-}

    # set the global attibutes
    _job_pool_pool_size=$pool_size
    _job_pool_echo_command=$echo_command

    # temporary directory
    _job_pool_dir=$(mktemp -d || { mkdir "/tmp/job-pool-$$" && echo "/tmp/job-pool-$$"; })
    if [[ ! -d $_job_pool_dir ]]; then
        echo "Could not create temporary directory" >&2
        exit 254
    fi

    # job queue used to send jobs to the workers
    _job_pool_job_queue="${_job_pool_dir}"/job_queue

    # where results got logged
    _job_pool_result_log="${_job_pool_dir}"/result_log

    # create the fifo job queue and create the exit code log
    mkfifo "${_job_pool_job_queue}" || exit 254
    touch "${_job_pool_result_log}" || exit 254

    # fork off the workers
    _job_pool.start_workers "${_job_pool_job_queue}" "${_job_pool_result_log}"
}

# \brief waits for all queued up jobs to complete and shuts down the job pool
function job-pool.shutdown()
{
    _job_pool.stop_workers
    _job_pool.print_result_log
    _job_pool.cleanup
}

# \brief run a job in the job pool
function job-pool.run()
{
    if [[ "${_job_pool_pool_size}" == "-1" ]]; then
        job-pool.init 1
    fi
    printf "%s\\v" "$@" >> "${_job_pool_job_queue}"
    echo >> "${_job_pool_job_queue}"
}

# \brief waits for all queued up jobs to complete before starting new jobs
# This function actually fakes a wait by telling the workers to exit
# when done with the jobs and then restarting them.
function job-pool.wait()
{
    _job_pool.stop_workers
    _job_pool.start_workers "${_job_pool_job_queue}" "${_job_pool_result_log}"
}
#########################################
# End of Job Pool
#########################################
