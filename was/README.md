# was

[Shrubbery](https://docs.racket-lang.org/shrubbery/) notation for
[Wax](https://github.com/marianoguerra/wax-mb): a second reader for the same
language, producing the same AST.

```
type ints = [i32]

export "sum" fn sum(arr :: &ints) -> i32:
  let total :: i32 = 0
  let i :: i32 = 0
  while i <~ arr.length():
    total += arr[i]
    i += 1
  total
```

That file and its `.wax` original compile to the same bytes. Three harnesses
assert it, over ten corpus programs and the whole of
`stdlib/collections/hashing.wax`:

- **the pair** — compile the `.wax` and the `.was` and compare the bytes;
- **the round trip** — read the `.was`, print it, read that, compare the bytes.
  This tests the *reader* harder than the printer: a form printed differently
  from how it was written still has to mean the same thing;
- **`wax -f was`** — take Wax's own parse tree, print it, read it back, compare
  against compiling the `.wax` directly. No was parse tree anywhere in that
  path, so it asks only whether the notation can say what Wax produced.

Byte equality is the assertion because it fails on a wrong signedness, a wrong
field order, a wrong label or an instruction in the wrong place.

## What changed, and why

Shrubbery already owns five of the characters Wax spends. Everything below is
forced; nothing is preference.

| wax | was | why |
|---|---|---|
| `x: i32` | `x :: i32` | `:` opens a block, once, at the end of a group |
| `{ … }` block | `:` and indentation | same |
| `'label` | `~label` | `'…'` is a shrubbery bracket pair |
| `'A'` | `char"A"` | same |
| `#[export = "n"]` | `export "n"` prefix | `#` is reserved |
| `a \| b` | `a \|\| b` | a bare `\|` introduces alternatives |
| `<s <u /s /u %s %u >>s >>u` | `<~ <$ /~ /$ %~ %$ >>~ >>$` | no shrubbery operator may contain a letter |
| `[t\| a, b]` | `t[a, b]` | `\|` again |
| `[t\| v; n]` | `t[v ** n]` | `;` cannot separate groups inside `[…]` |
| `[t\| d @ off; n]` | `t[d at off ** n]` | `@` is at-notation |
| `if c {…} else {…}` | `if c \| … \| …` | alternatives |
| `match v { p: &t => … }` | `match v \| p :: &t: …` | alternatives |
| `try t {…} catch {…}` | `try -> t: … \| tag: …` | a block, then alternatives |

`~` is signed and `$` is unsigned, and a bare operator is the one Wax leaves
unannotated: float division, float comparison, reference identity. That keeps
all three of Wax's forms rather than defaulting one of them, so was changes how
the language is spelled and never what it means.

Two characters that look taken are not. `::` is the annotation operator only in
binder position, so `i64::add128(a, b)` still reads as a qualified intrinsic.
And a multi-character operator may contain `|`, so `|=` survives untouched even
though `|` alone does not.

## Using it

```sh
moon add marianoguerra/was
```

```moonbit
@was.compile_string(src)          // -> Result[Bytes, Diagnostics]
@was.compile_string_to_wat(src)   // the same module, printed
@was.fields(src)                  // -> the Wax AST, and nothing further
@was.print_module(fields)         // -> the other direction
@was.format_string(src)           // read it, print it back
```

`print_module` is what makes `wax -f was` and `wap -f was` real. It takes any
Wax AST -- from this reader, from Wax's own parser, from `marianoguerra/wap`'s
lowering, from a generator -- and writes it as was.

`fields` is the seam. What comes back is indistinguishable from what the Wax
parser produces for the equivalent `.wax` file, so a project can read was, add
fields built with `marianoguerra/wax/ast/build`, and compile the lot.

Diagnostics are `marianoguerra/error-report` reports for grouping problems and
Wax's own for everything after, and both point into the `.was` file: spans are
mapped through rather than synthesised, so a Wax type error lands on the line
that caused it.

## Packages

| package | what |
|---|---|
| `marianoguerra/was` | the facade: source to Wax AST, wasm or wat |
| `marianoguerra/was/read` | the reader |
| `marianoguerra/was/print` | the printer |

## What is covered

Types (`open`, supertypes, `descriptor`/`describes`, structs, arrays, function
and continuation types, the `..` splice), `rec` groups, functions, globals,
tags, memories, tables, element and data segments, import groups, module
features and `cfg` conditionals; and for instructions: `let`, assignment and
its compound forms, `:=`, every binary and unary operator, `as`/`is`/`on`,
casts including `as i32_u` and `as ?descriptor(d)`, struct and array literals in
all four array forms, field and element access and assignment, calls, labelled
arguments, `if`, `do`, `loop`, `while` with a step, `match`, `dispatch`,
`try`/`catch` and `try on [...]`, every `br` family member, `return`, `become`,
`throw`, `throw_ref` and `suspend`.

## What is not

- **The printer needs a value to fit on a line.** A conditional used as a value
  prints as `(if c | a | b)`, which shrubbery allows inside parentheses but
  only when each branch is one expression. A multi-instruction branch in a
  value position has no inline spelling and prints a marker that fails to read
  back, loudly, rather than something plausible.
- **`?:` is gone.** Its `:` would open a block. Write `if c | a | b`, which is
  an expression here.
- **One-element array literals need the type.** `ints[0]` is a literal and
  `xs[0]` is an index, told apart by whether the name is a declared type —
  because Wax puts the type inside the brackets and shrubbery has nowhere to
  keep the marker. A local that shadows a type name will read as the type.
- **SIMD literals and NaN payloads** are not spelled yet; `#inf` and `#nan` are.

## Development

`was/` is a member of the `wax-mb` workspace. From the repository root:

```sh
moon check --deny-warn
moon test
```

`stdlib-was/` holds translations of Wax standard library modules, and the tests
in this module compile both versions and compare the bytes.
