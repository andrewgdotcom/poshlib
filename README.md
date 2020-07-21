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

## Initialisation

Incant the following at the top of your script:

```
. /path/to/poshlib/init
```

You can now enable the separate modules with the command `use MODULE`.

## Modules

### parse-opt - boilerplate wrapper for extended getopt(1)

This module defines no functions, as it can only be invoked once per shell. You should define the associative arrays PO_SHORT_OPTIONS and PO_LONG_OPTIONS *above* the `use parse-opt` invocation, below which the named variables are populated with the arguments to their corresponding command line flags. The flags and arguments are excised from ARGV leaving only positional arguments.

### swine - make bash a little bit more like perl

This module sets some shell option defaults to make it more like perl's `strict`, and defines the functions:

* die
* contains
*

### flatten - convert a poshlib script with `use` dependencies into a flat script

This is useful if you are passing a script via ansible to a machine that does not have poshlib installed. It defines one function:

* flatten
