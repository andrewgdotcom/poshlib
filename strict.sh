# shellcheck disable=SC2148
################################################################################
# Bash unofficial strict mode
# c.f. http://redsymbol.net/articles/unofficial-bash-strict-mode/
#
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

set -o errexit
set -o pipefail
set -o nounset
__posh__err_report() {
    echo "errexit $? on line $(caller)" >&2
}
trap __posh__err_report ERR
