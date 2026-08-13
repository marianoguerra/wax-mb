# marianoguerra/wax-cli

`wax-mb`, the command-line tool for the [Wax](https://github.com/ocsigen/wax)
language: convert, format and check.

The language itself is [`marianoguerra/wax`](https://mooncakes.io/docs/marianoguerra/wax).
This module is only the tool around it — argument parsing, file IO, terminal
detection, colour, exit codes. It exists separately so that the library can
have no dependencies at all: a module's dependencies are fetched by everyone who
depends on it, and an embedder that just wants the type checker should not be
made to fetch `moonbitlang/x` for filesystem access it never calls.

## Install

```sh
moon install marianoguerra/wax-cli
```

## Use

```sh
wax-mb f.wax                  # convert: reformat to stdout
wax-mb f.wax -f wasm -o f.wasm   # compile to a binary
wax-mb f.wax -f wat           # compile to WebAssembly text
wax-mb check f.wax            # report diagnostics, produce no output
wax-mb format -i src/*.wax    # reformat in place
wax-mb format --check src/*.wax  # list the files that would change
```

The command name, flags and exit codes follow the reference implementation's,
because the reference's own cram tests are run against this binary unedited.

| status | |
|---|---|
| 0 | every file passed |
| 123 | an invalid combination of flags, or `--check` found files needing formatting |
| 124 | an unknown flag or a bad option value |
| 125 | an uncaught internal error |
| 128 | the input was rejected by a diagnostic |

`123` and `124` are *how you used the tool*; `128` is *the input is bad*. A CI
gate can tell a broken invocation from a rejected file.

## Warnings

`-W name=level` sets one warning's level; `level` is `hidden`, `warning` or
`error`. `WAX_WARN` takes the same specs, separated by commas or whitespace,
and is applied before the flags — so a suite can hide a whole group in the
environment and one test can re-enable the single warning it is about.

## Diagnostics

`--error-format human` (the default), `json` or `short`. `--color always`,
`never` or `auto`; `auto` looks at whether the *destination* is a terminal, so a
redirect never receives escape codes.

## Licence

Apache-2.0.
