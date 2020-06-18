#!/bin/bash
set -o errexit
set -o pipefail
#set -o noclobber
#set -o nounset

SCRIPT_DIR=$(dirname $(readlink -f $0))

#####
# Set defaults here e.g. via envars, config
#####

declare -A PO_SHORT_MAP
PO_SHORT_MAP["d::"]="DEBUG=x y z"
PO_SHORT_MAP["v"]="VERBOSE"
PO_SHORT_MAP["f"]="FORCE"

declare -A PO_LONG_MAP
PO_LONG_MAP["output:"]="OUTPUT"
PO_LONG_MAP["input:"]="INPUT"
PO_LONG_MAP["verbose"]="VERBOSE"
PO_LONG_MAP["force"]="FORCE"

declare -A expected_output
expected_output[' ']=",,,,;"
expected_output['foo bar wibble']=",,,,;foo bar wibble"
expected_output['foo -d bar wibble']="x y z,,,,;foo bar wibble"
expected_output['foo bar -d- wibble']="-,,,,;foo bar wibble"
expected_output['foo -- bar -d- wibble']=",,,,;foo bar -d- wibble"
expected_output['-f --no-force']=",false,,,;"
expected_output['--no-force -f']=",true,,,;"
expected_output['--output=- --input "--" ']=",,,-,--;"
expected_output['--output="A +" --input "a # c" ']=",,,A +,a # c;"
#expected_output['-f -x -d']=",true,,,;-f -x -d"

for input in "${!expected_output[@]}"; do
    eval set -- $input
    . ${SCRIPT_DIR}/../parse-opt.sh
    output="$DEBUG,$FORCE,$VERBOSE,$OUTPUT,$INPUT;$*"
    if [[ "$output" != "${expected_output[$input]}" ]]; then
        echo "Failed on '$input'"
        echo "   expect '${expected_output[$input]}'"
        echo "      got '$output'"
    fi
    DEBUG= FORCE= VERBOSE= OUTPUT= INPUT=
done
