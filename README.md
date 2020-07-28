# poshlib
A posix shell utility library

To include in your git project, incant the following inside your git repo:

```
git submodule add https://github.com/andrewgdotcom/poshlib
git submodule sync --recursive
git submodule update --init --recursive
```

or alternatively, if you are using git+ssh:

```
git submodule add git@github.com:andrewgdotcom/poshlib
git submodule sync --recursive
git submodule update --init --recursive
```

To update your project to use the latest version of poshlib, incant:

```
git submodule update --recursive --remote poshlib
git commit -m "Update poshlib" poshlib
```

## Initialisation

Incant the following at the top of your script:

```
. /path/to/poshlib/poshlib.sh
```

You can now enable the individual modules with `use MODULE`.

You can extend poshlib with your own modules by appending paths to the envar `USEPATH`, using the same colon-separated format as `PATH`. The default `USEPATH` is `/path/to/poshlib`.

## Modules

### parse-opt - boilerplate wrapper for extended getopt(1)

This module provides routines for parsing GNU-style longopts. All of the functions *must* be invoked using `eval` in order to modify the calling script's ARGV.

The full-featured version is:

* eval $(parse-opt-init)
* eval $(parse-opt)

You MUST populate the associative arrays PO_SHORT_OPTIONS and PO_LONG_OPTIONS after `eval $(parse-opt-init)` and before `eval $(parse-opt)`. The named variables are initialised with the arguments to their corresponding command line flags. The options are excised from ARGV leaving only positional arguments.

Alternatively one can use a simplified system, at the cost of flexibility:

* eval $(parse-opt-simple)

This automatically creates the mappings between options and environment variables, however it is not possible to specify default values or short options using this method.

See the comments at the top of parse-opt.sh for full instructions.

### swine - make bash a little bit more like perl

This module sets some shell option defaults to make it more like perl's `strict`, and defines the functions:

* say
* warn
* die
* contains

### flatten - convert a poshlib script with `use` dependencies into a flat script

This is useful if you are passing a script via ansible to a machine that does not have poshlib installed. It defines one function:

* flatten

### rposh - run a poshlib script with `use` dependencies on a remote environment

* rscript
