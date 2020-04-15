[![CircleCI](https://circleci.com/gh/hanshoglund/music-suite.svg?style=svg)](https://circleci.com/gh/hanshoglund/music-suite)

# Music Suite

Music Suite is a language for describing music, based on Haskell.

<!-- See <http://music-suite.github.io>. -->


## How to build

### Set up the build environment

Install Nix (2.3.1 or later).

Enter build environment using:

```
nix-shell --pure
```

Inside the build shell, the following commands can be used:

### Build the library and examples

```
music-suite-build$ cabal update
music-suite-build$ cabal build
```

### Build and run the tests

#### Property tests

```
music-suite-build$ cabal test
```

To run individual tests:

```
music-suite-build$ cabal run TEST_NAME -- TEST_ARGS...
```

#### Doctests

```
music-suite-build$ cabal build && cabal exec --package music-suite -- cabal run doctester PATHS
```

where `PATHS` is a list of Haskell files or directories containing Haskell files.

For now, `default-extensions` is not recognized, so you must list the extensions
explicitly in each file using a `LANGUAGE` pragma.

### Development shell

```
music-suite-build$ cabal build music-suite && cabal exec --package music-suite ghci
```

### Build the documentation

#### User Guide

```
music-suite-build$ cabal build music-suite transf hslinks && (cd docs && make)
```

The output appears in `docs/build`. You can point a HTTP server to this directory.

#### API docs

```
music-suite-build$ cabal haddock
```


## How to upgrade the compiler/Nixpkgs

- Update the commit/URL and hash in `default.nix`
  - Use `$ nix-prefetch-url --unpack <url>` to obtain the hash (and verify)
- Enter new Nix shell (may take a while)
- Comment out `reject-unconstrained-dependencies` in Cabal config
- Update `index-state` in Cabal config to a recent time
- Run `cabal freeze`
- Run `cabal test` to check that compiling/testing works (and fix errors)
- Restore `reject-unconstrained-dependencies`
- Commit changes to Nix and Cabal files

