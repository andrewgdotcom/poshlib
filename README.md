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

These files should be sourced to modify the behaviour of the current shell.

* parse-opt.sh - boilerplate wrapper for extended getopt(1)
* swine.sh - make bash a little bit more like perl
