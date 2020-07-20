################################################################################
# Make bash a little bit more like perl. Turn on strict error handling, and
# implement some of the more useful perl native functions.
# See: https://perldoc.perl.org/5.32.0/index-functions.html
# This file has no magic number, and is not executable.
# THIS IS INTENTIONAL as it should never be executed, only sourced.
################################################################################

set -euo pipefail;
err_report() {
    echo "errexit on line $(caller)" >&2
};
trap err_report ERR

# DIE takes two arguments, unlike perl
# die <errnum> <string>

die() {
    echo $2 >&2
    exit $1
}
