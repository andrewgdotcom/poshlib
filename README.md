# poshlib
A POSIX shell utility library

This library adds modern programming-language features to POSIX shells.
It depends on a small number of commonly installed POSIX tools:

* grep
* sed
* getopt (extended)
* flock (job-pool module only)
* ssh (ControlMaster support required, rposh module only)

Note that extended `getopt` and `flock` are not shipped with MacOS, and must be installed via e.g. MacPorts or Homebrew.

Currently only bash v3.2+ is supported.


## Installation

Copy this entire tree into a subdirectory of your project and skip to "Usage" below.

### Git submodule

To include as a git submodule, incant the following inside your git repo:

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

## Usage

Source the `poshlib.sh` file at the top of your script.
If your script will be bundled with its dependencies, it is recommended to do this using a constructed path.
For example, if poshlib is installed in a sibling directory of the calling script, the following can be used:

```
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
. "$SCRIPT_DIR/poshlib/poshlib.sh" || exit 1
```

NOTE that some poshlib routines (e.g. rscript) expect the second line above to be in a narrowly-defined format, otherwise they will fail to resolve the dependencies correctly (this avoids having to reimplement a shell parser).
Please try not to deviate too far from the example form above, otherwise you may get errors of the form "Unexpected descent before init".

You can now enable the individual modules with:

```
use <module>
```

Module names are the filenames without the `.sh` suffix.

You can extend poshlib with your own modules:

```
use-from <path>
```

This prepends the given path to the module search path.
Relative paths are relative to the script location.
The default search path contains the directory from which poshlib.sh has been sourced.


## Optional modules

### strict - shell "strict mode"

This sets `-euo pipefail` and enables some basic default error handling.
Note that this is NOT a panacea and has significant side effects.
It is *strongly recommended* that you also use a linter such as shellcheck (https://shellcheck.net).

See e.g. http://redsymbol.net/articles/unofficial-bash-strict-mode/ (but note that `strict` *does not* alter $IFS globally as this changes the semantics of shell scripts in a non-obvious yet invasive manner)

With strict mode on, there are specific extra precautions you should take when writing code:

#### Use explicit default values on variables

You may need to handle variables that might be intentionally unset (optional parameters, environment vars etc).
If so, setting a default value is vital to prevent unset-parameter errors.

To use a default value in situ, use:

```
echo "${variable-"default value"}"
```

To set a default value indefinitely, use the construction:

```
: "${variable="default value"}"
```

You should always quote the default value if it contains whitespace, special characters, or a variable expansion.

Default values should also be used in conditional statements such as:

```
if [[ $1 ]]; then echo "$1"; fi
```

The above is *unsafe*. It should be replaced with:

```
if [[ ${1-} ]]; then echo "$1"; fi
```

Note that default values can also be used to replace empty (but not unset) variables.
To replace both unset *and* empty variables, use `:-` or `:=` as appropriate:

```
echo "${variable:-"default value"}"
: "${variable:="default value"}"
```

#### Use null-safe array expansions

If you need to support bash v4.3 or earlier (e.g. CentOS 7 or Darwin/MacOS), then you should *never* use the idiom:

```
"${array[@]}"
```

If the array is defined but empty, it will exit with an `unbound variable` error  
(this is a design flaw in bash that was finally fixed in v4.4).
You should instead use the following incantation WITHOUT surroundng double quotes (yes, really):

```
${array+"${array[@]}"}
```

https://stackoverflow.com/questions/7577052/bash-empty-array-expansion-with-set-u/61551944#61551944

You can find unsafe array expansions with the following one-liner:

```
grep -ER '([^+])("\$\{([^[{}]+)\[?@\]?\}")([^{]|$)'
```

And this one-liner *should* replace them with their safe counterparts 
(however you MUST manually check the resulting code for errors, as this is not foolproof).

```
sed -Ei 's/([^+])("\$\{([^[{}]+)\[@\]\}")([^{]|$)/\1\${\3+\2}\4/g'
```

#### Beware of return codes from subcommands

It is quite common in shell scripting to pass a stream of data through a subcommand such as `grep` or `awk`.
You should beware that `grep` in particular will exit with a failure code if it does not match any data.

The following is *unsafe*:

```
lines=$(grep "foo" /tmp/data)
```

If no lines in `/tmp/data` match, this will throw an error and exit.
If empty output from `grep` is expected, you will need to add an explicit `|| true`:

```
lines=$(grep "foo" /tmp/data || true)
```

Note that since `strict` sets `-o pipefail`, this has to be done even if `grep` is not the last command in the pipeline:

```
lines=$(grep "foo" /tmp/data | sort -u || true)
```

Confusingly, `awk` will *NOT* generally return an error code on no match.

#### Don't use `$?`

If you need to distinguish between different nonzero return codes, the module `swine` implements a simple `try/catch` utility (see below).


#### Don't use `&&` as a guard operator

The use of `||` as a guard operator traps and handles nonzero return codes consistently, but the corresponding `&&` operator *does not*.

For example, the following is *not safe*:

```
my_function() {
    [[ $test == "true" ]] && do_something
}
```

If `$test` is not "true", and this is the last line of a script or function, then the script or function will exit with a nonzero error code (but *not fail*!).

To avoid, you can either use the converse `||` construction consistently:

```
[[ $test != true ]] || do_something
```

OR you can get into the habit of always ending scripts / functions with explicit `exit 0` / `return 0` statements.

#### Don't use `let` / `(( ))` outside a conditional without forcing its anomalous return code

`let` and its modern equivalent `(( ))` return nonzero if the last expression in the (comma-separated) argument list evaluates to zero.

https://unix.stackexchange.com/questions/32250/why-does-a-0-let-a-return-exit-code-1

This is designed so that flow control statements such as `if`, which are designed to operate on the return codes of *commands*, can also operate on expressions in a similar way to other programming languages:

```
if (( a < b + c )); then
    echo "a is lesser"
fi
```

Without the anomalous error return code of `let`, this would have to be implemented as:

```
if [[ $(( a < b + c )) == 1 ]]; then
    echo "a is lesser"
fi
```

(Note carefully the conventional (C-style) use of 0==false and 1==true as the result of `let` equality tests, the opposite way around from the shell's handling of error codes)

Each of the following lines is therefore counterintuitively *unsafe*:

```
let "a=b-c"
(( a++ ))
```

There are several workarounds.
Which one is more appropriate will depend on context and personal taste.

* replace `(( variable = expression ))` with `variable=$(( expression ))`
* replace `(( expression ))` with `(( expression , 1 ))` to force success

The following are safe:

```
a=$(( b-c ))
(( a++ , 1 ))
```

#### Don't test the return value of functions or complex commands

When complex commands, subshells, functions etc. are used in the conditional of a flow control command, all errors are discarded by the flow control statement.
This is because flow control works by temporarily *globally* disabling error checking and then checking `$?` at the end of the conditional.

The following are all *unsafe*:

```
f() { false; true; }
if f; then
    do_something
fi
if ( false; true; ); then
    do_something
fi
if { false; true; }; then
    do_something
fi
```

This can lead to unexpected behaviour inside the function if its design assumes that it will return immediately on error.

https://fvue.nl/wiki/Bash:_Error_handling

### ansi - macro definitions for ANSI terminal formatting

See `ansi.sh` for a full list of formatting macros

### ason - serialisation and deserialisation routines [EXPERIMENTAL]

ASON is a lightweight serialisation format which enables complex data structures to be passed as strings,
for data transfer between shell functions, subcommands, pipelines etc.

Currently only `LIST` types are implemented. See `ason.sh` for usage details.

### fakehash - emulate associative arrays in shells that don't provide them

Emulate an associative array using two regular arrays.

It defines the following functions:

* `fakehash.declare hash`
* `fakehash.get hash key [key ...]`
* `fakehash.read-a array hash key [key ...]`
* `fakehash.keys.read-a array hash`
* `fakehash.update hash key=value [key=value ...]`
* `fakehash.remove hash key [key ...]`
* `fakehash.compact hash`
* `fakehash.unset hash`

The algorithm is inefficient and does not implement an actual hash, nor does it use sparse arrays.
There is a specific `fakehash.compact` function that should be called periodically to recover memory.

### flatten - convert a poshlib script with `use` dependencies into a flat script

It defines one function, which prints the flattened script on STDOUT:

* `flatten "$script"`

This is useful if you want to pass a poshlib script to a non-poshlib-aware tool, e.g. ansible.

### job-pool - simple parallelisation tool

This defines the following functions:

* `job-pool.init "$pool_size" "$echo"`
* `job-pool.run "$command" ["$arg1" ...]`
* `job-pool.wait`
* `job-pool.shutdown`

They should be always be invoked in the sequence above.
$pool_size is the number of workers, and $echo is "0" for silence or "1" otherwise.

It also defines the following public variables:

* `$job_pool_nerrors`
    the cumulative number of errors recorded by the previous run

### keyval - tool to (more) safely read key-value pairs from shell-script-like files

It defines the following functions to manipulate shell-like variable definitions in arbitrary files:

* `value=$(keyval.read [--no-strip] "$file" [KEY])`
* `keyval.import [--no-strip] "$file" [KEY]`
* `keyval.add [--no-update] [--multi] [--match-indent] "$file" KEY "$value"`
* `keyval.update [--no-add] [--match-indent] "$file" KEY "$value"`
* `keyval.delete [--comment] "$file" KEY`

`KEY` may be a simple variable name, or an array member in the form `ARRAY[index]`.
(BEWARE that for safety reasons hash indexes MUST NOT contain special characters; unexpected behaviour may result)

`keyval.add` and `keyval.update` can operate on individual array or hash elements using the format `ARRAY[index]=VALUE`.
There is (currently) no support for serialising an entire array or hash to a file in one command.
Note that each will fall back on the other's behaviour unless `--no-add` or `--no-update` (as appropriate) is given.
Therefore without `--no-*` they differ only in the order of operations tried.

If the option `--multi` is passed to `keyval.add` it will not overwrite any existing definition.
This is useful for adding multiple entries for the same key in the same file (some tools treat this as a feature, e.g. rkhunter).
`keyval.read` will output all matching entries separated by newlines, but the order is not well-defined.

If the option `--match-indent` is passed to `keyval.add` or `keyval.update` they will attempt to preserve leading whitespace when inserting or uncommenting lines.
By default any new or uncommented lines will be left-justified, as leading whitespace is not universally supported.

`keyval.delete` can operate on individual elements or entire arrays.
If `--comment` is given entries in the file are commented out rather than deleted.

`keyval.read` can only read arrays or hashes in bulk; use shell parameter expansion to get individual elements.
Enclosing quotes around values will be silently stripped unless `--no-strip` is given.

`keyval.import` operates similarly to `keyval.read` but instead of printing the key=value pairs on STDOUT, it directly assigns variables in the calling environment.
Importing a nonexistent key does not delete the corresponding variable, nor does reading an array remove non-matching members.
If this behaviour is required, then the variable/array should be explicitly cleared before calling `keyval.import`.

### main - make a `use`-able script executable

`main` can be used to make a script dual-purpose, i.e. it can be sourced with `use` or it can be executed directly.
To avail of this, all its functionality should be contained within shell functions, and then the main function should be declared at the bottom of the file thus:

```
main main_function "$@"
```

This statement will invoke `main_function` with the script arguments IFF the script has been executed.
If the script has been sourced or used, then it will do nothing and it is the responsibility of the sourcing script to invoke any functions at a later point.

### parse-opt - routines for parsing GNU-style longopts

This requires extended getopt.
Note that Darwin/MacOS does NOT ship extended getopt by default; it must be installed via e.g. MacPorts or Homebrew.

Simple usage:

```
use parse-opt

parse-opt.prefix PREFIX_
parse-opt.params PARAM [PARAM ...]
parse-opt.flags FLAG [FLAG ...]

eval "$(parse-opt-simple)"
```

Any longopt arguments are excised from "$@" and their values assigned to shell variables, leaving only positional arguments in "$@".
The argument names are kebab-case, and the corresponding shell variables are UPPER_SNAKE_CASE, with an optional prefix for simple namespacing.

See the comments at the top of parse-opt.sh for full usage instructions.

### rposh - run a poshlib script with `use` dependencies on a remote environment

This requires a version of ssh(1) that supports ControlMaster.

* `rscript "$host" "$script"`

### swine - make bash a little bit more like perl

This module sets strict mode (see above), and also defines some useful perl-like functions:

* `say "$text"`
    * prints a line on STDOUT without parsing special characters
* `warn "$text"`
    * like say, but for STDERR
* `die "$errcode" "$text"`
    * warns and exits the current (sub)shell with a given error code
* `try "$command" ; if catch e; then ...`
    * captures the error code of a simple command for testing
* `contains "$string" "${values[@]}"`
    * succeeds if a string is contained in an array or list of strings (but BEWARE of null-safe expansions, see above)

Note that try works by calling `eval` on its arguments, so they should be quoted accordingly.
It does not work reliably on complex commands, subshells, or functions.
This is a design limitation of `bash`.

### tr - replace trivial calls to `tr` with internal functions where possible

This module replaces some common uses of external `tr` with internal shell functions if the calling shell supports them.
Some older versions of `bash` (e.g. MacOS's v3.2) have limited native support for string manipulation.
This can reduce resource usage in most cases.

It implements the following variable-manipulation functions:

* `tr.kebab-case var [dest]`
* `tr.snake_case var [dest]`
* `tr.UPPER-KEBAB-CASE var [dest]`
* `tr.UPPER_SNAKE_CASE var [dest]`

They each take one argument, the name of a variable to modify.
If a second variable name is given, the modified text is written to it.
If no second variable name is given, the first variable is modified in-place.

It also implements the following stream-editing functions:

* `tr.mapchar $old $new`

This replaces every instance of `$old` with `$new` in a stream.

### wc - replace system `wc` with internal functions

`wc` does not produce machine-readable output on all platforms.
This module replaces the most common use cases of system `wc` with predictable forms:

* `wc.words`
    Counts the number of words on STDIN.
* `wc.lines`
    Counts the number of line breaks on STDIN.
* `wc.chars`
    Counts the number of characters on STDIN.
* `wc.count CHAR`
    Counts the number of occurrences of CHAR in STDIN.

## Notes

* poshlib currently only works reliably with `bash`, but it is intended to (eventually) also support other POSIX shells.
* It is conventional for poshlib modules to prefix their public function member names with `module.` and public variable member names with `module_` or `MODULE_`.
    The corresponding conventions for private members are the same, but with leading underscores.
    If you are extending poshlib with your own modules, it is recommended to follow this convention.
    Some modules provide other public member names for backwards compatibility; these are all currently deprecated and will be removed in a future version.
