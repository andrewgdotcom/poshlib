# poshlib
A posix shell utility library

To include in your project, incant the following inside your git repo:

```
git submodule add https://github.com/andrewgdotcom/poshlib
git submodule sync --recursive
git submodule update --init --recursive
git commit -m "Add poshlib" poshlib
```

or alternatively, if you are using git+ssh:

```
git submodule add git@github.com:andrewgdotcom/poshlib
git submodule sync --recursive
git submodule update --init --recursive
git commit -m "Add poshlib" poshlib
```

To update your repo to use the latest version of poshlib, incant:

```
git submodule update --recursive --remote poshlib
git commit -m "Update poshlib" poshlib
```

When cloning your repo, users should incant:

```
git clone --recurse-submodules <REPO>
```

And when refreshing that clone, they should use:

```
git pull --recurse-submodules
```

IFF you have users who have already cloned a version of your repo that did not use submodules, and are updating to a version that does, they will need to initialise the submodules by hand:

```
git submodule sync --recursive
git submodule update --init --recursive
```

## Initialisation

Source the `poshlib.sh` file at the top of your script. It is often useful to do this using a relative path. For example, if the poshlib repo is a sibling of the calling script, the following can be used:

```
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/poshlib/poshlib.sh" || exit 1
```

NOTE that some poshlib routines (e.g. rscript) expect the second line above
to be in a narrowly-defined format, otherwise they will fail to resolve the
dependencies correctly (this avoids having to reimplement a shell parser).
Please try not to deviate too far from the example form above, otherwise you
may get errors of the form "Unexpected descent before init".

You can now enable the individual modules with:

```
use <module>
```

Module names are the filenames without the `.sh` suffix.

You can extend poshlib with your own modules:

```
use-from <path>
```

This prepends the given path to the module search path. Relative paths are relative to the script location. The default search path contains the directory from which poshlib.sh has been sourced.


## Optional modules

### ansi - macro definitions for ANSI terminal formatting

See ansi.sh for a full list of formatting macros

### ason - serialisation and deserialisation routines

ASON is a lightweight serialisation format which enables complex data structures
to be passed as strings. It requires no helper programs other than sed/awk.

Currently only LIST types are implemented. See ason.sh for usage details.

### flatten - convert a poshlib script with `use` dependencies into a flat script

It defines one function, which prints the flattened script on STDOUT:

* flatten "$script"

This is useful if you want to pass a poshlib script to a non-poshlib-aware tool, e.g. ansible.

### job-pool - simple parallelisation tool

This defines four functions:

* job_pool_init "$pool_size" "$echo"
* job_pool_run "$command" ["$arg1" ...]
* job_pool_wait
* job_pool_shutdown

They should be always be invoked in the sequence above. $pool_size is the number of workers, and $echo is "0" for silence or "1" otherwise.

### keyval - tool to (more) safely read key-value pairs from shell-script-like files

It defines four CRUD functions to manipulate shell-like variable definitions in arbitrary files:

* eval $(keyval-read [--no-strip] "$file" [KEY])
* keyval-add [--no-update] "$file" KEY "$value"
* keyval-update [--no-add] "$file" KEY "$value"
* keyval-delete [--comment] "$file" KEY

`KEY` may be a simple variable name, or an array member in the form `ARRAY[index]`.
(BEWARE that special characters in hash indexes are not thoroughly tested and may not work as expected)

`keyval-add` and `keyval-update` can operate on individual array or hash elements using the format `ARRAY[index]=VALUE`.
There is (currently) no support for serialising an entire array or hash to a file in one command.
Note that each will fall back on the other's behaviour unless `--no-add` or `--no-update` (as appropriate) is given.
Therefore without `--no-*` they differ only in the order of operations tried.

`keyval-delete` can operate on individual elements or entire arrays.
If `--comment` is given entries in the file are commented out rather than deleted.

`keyval-read` can only read arrays or hashes in bulk; use shell parameter expansion to get individual elements.
Enclosing quotes around values will be silently stripped unless `--no-strip` is given.
Note that the output of `keyval-read` must be `eval`ed in order to manipulate variables in the calling script.
Reading a nonexistent key does not delete the corresponding variable, nor does reading an array remove non-matching members;
if this behaviour is required, then the variable/array should be explicitly cleared before calling `keyval-read`.

### main - make a `use`-able script executable

`main` can be used to make a script dual-purpose, i.e. it can be sourced with `use` or it can be executed directly. To avail of this, all its functionality should be contained within shell functions, and then the main function should be declared at the bottom of the file thus:

```
main main_function "$@"
```

This statement will invoke `main_function` with the script arguments IFF the script has been executed. If the script has been sourced or used, then it will do nothing and it is the responsibility of the sourcing script to invoke any functions at a later point.

### parse-opt - routines for parsing GNU-style longopts

This requires extended getopt(1). All of the functions *must* be invoked using `eval` in order to modify the calling script's ARGV.

The full-featured version is:

```
eval "$(parse-opt-init)"
PO_SHORT_MAP[...]= ...
PO_SHORT_MAP[...]= ...
PO_LONG_MAP[...]= ...
PO_LONG_MAP[...]= ...
eval "$(parse-opt)"
```

The associative arrays PO_SHORT_MAP and PO_LONG_MAP denote mappings between command-line flags and environment variables into which the values of the parameters are stored. The command-line flags are excised from ARGV leaving only positional arguments.

Alternatively one can use a simplified system, at the cost of flexibility:

```
PO_SIMPLE_PREFIX= ...
PO_SIMPLE_PARAMS= ...
PO_SIMPLE_FLAGS= ...
eval "$(parse-opt-simple)"
```

This automatically creates the mappings between options and variables (so that e.g. the value of the parameter --foo-bar is stored in the environment variable FOO_BAR), however it is not possible to specify default values or short options using this method.

See the comments at the top of parse-opt.sh for full usage instructions.

### rposh - run a poshlib script with `use` dependencies on a remote environment

This requires a version of ssh(1) that supports ControlMaster.

* rscript "$host" "$script"

### swine - make bash a little bit more like perl

This module sets some shell option defaults to make it more like perl's `strict`, registers an error handler that prints better debugging info, and defines some useful functions:

* say "$text"
    * prints a line on STDOUT without parsing special characters
* warn "$text"
    * like say, but for STDERR
* die "$errcode" "$text"
    * warns and exits the current (sub)shell with a given error code
* try "$command" ; if catch e; then
    * captures the error code of a simple command for testing
* contains "$string" "${values[@]}"
    * succeeds if a string is contained in an array or list of strings

Note that try works by calling `eval` on its arguments, so they should be
quoted accordingly. It does not work well for complex commands, subshells etc.

## Notes

* poshlib currently only works with bash, but it is intended to (eventually) also support other POSIX shells.
