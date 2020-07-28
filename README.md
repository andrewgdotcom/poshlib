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
. $SCRIPT_DIR/poshlib/poshlib.sh
```

You can now enable the individual modules with `use MODULE`. Module names are the filenames without the `.sh` suffix.

You can extend poshlib with your own modules by appending paths to the envar `USEPATH`, in the same colon-separated format as `PATH`. The default `USEPATH` is `/path/to/poshlib`.

## Modules

### parse-opt - routines for parsing GNU-style longopts

This requires extended getopt(1). All of the functions *must* be invoked using `eval` in order to modify the calling script's ARGV.

The full-featured version is:

* eval $(parse-opt-init)
* eval $(parse-opt)

You must populate the associative arrays PO_SHORT_OPTIONS and PO_LONG_OPTIONS after `eval $(parse-opt-init)` and before `eval $(parse-opt)`. The named variables are initialised with the arguments to their corresponding command line flags. The options are excised from ARGV leaving only positional arguments.

Alternatively one can use a simplified system, at the cost of flexibility:

* eval $(parse-opt-simple)

This automatically creates the mappings between options and variables, however it is not possible to specify default values or short options using this method.

See the comments at the top of parse-opt.sh for full usage instructions.

### swine - make bash a little bit more like perl

This module sets some shell option defaults to make it more like perl's `strict`, registers an error handler that prints better debugging info, and defines some useful functions:

* say
* warn
* die
* contains

### flatten - convert a poshlib script with `use` dependencies into a flat script

It defines one function, which prints the flattened script on stdout:

* flatten

### rposh - run a poshlib script with `use` dependencies on a remote environment

* rscript
