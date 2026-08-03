# printer_pp — the same documents, a different engine

`printer` is a streaming layout engine with bounded lookahead, ported from the
reference OCaml because byte-exact output is this project's whole point.
`printer_pp` answers the question that ports out of caution always leave open:
what would a general-purpose library have done instead?

The library is
[marianoguerra/pretty-fast-pretty-printer](https://mooncakes.io/docs/marianoguerra/pretty-fast-pretty-printer@0.1.0),
the MoonBit port of Brown PLT's `pretty-fast-pretty-printer`. It builds an
immutable `Doc` from four combinators — `txt`, `horz`, `vert`, `if_flat` — and
picks a layout in one left-to-right pass.

## What is shared, and what is not

Only the **layout** is swapped. The two engines are driven by the same
`@printer.Printer` — the imperative builder, with its break coalescing, its
deferred end-of-line comments and its `skip_space`. That builder never sees the
width, so the token stream it produces is engine-independent, and
`@printer.run_tokens` hands that exact stream to this package.

So `@printer_pp.run_string` is a drop-in for `@printer.run_string`: same
callback type, same width argument. `@output.render_with` exists to take
advantage of that, and `tools/ppdiff` uses it to hold the two engines up against
each other on the same 1900-module corpus.

```sh
just ppdiff
```

## The result

```
files scanned:   2114
modules parsed:  1903
identical:       1871
differing:       32
agreement:       98%

  overflow (fit decision ignores trailing context): 30
  indent   (no max_indent cap):                     2
  other:                                            0
```

1871 of 1903 modules come out **byte for byte identical**. Every one of the 32
that do not is one of the two differences below, both of which follow from the
library's model rather than from a mistake in the lowering. Nothing lands in
`other`, and if a change ever puts something there, that is a bug in this
package.

## The two differences

### 1. A fit decision ignores what follows the group

`if_flat(flat, broken)` takes `flat` when `column + flat.flat_width <= width`.
It weighs the group and nothing else, because that precomputed width is exactly
what makes the algorithm linear.

The streaming engine asks a different question. Its scan runs *past* the end of
the group, on to the next break that would end the line, so the closing `)`s and
the trailing `;` that follow the group count against it:

```moonbit
p.hvbox(() => {
  p.string("f(")
  p.hvbox(() => { p.string("aaaa"); p.space(); p.string("bbbb") })
  p.string("))")
})
```

At width 12 `printer` breaks the inner box, because `aaaa bbbb))` is 11 columns
after `f(`. `printer_pp` weighs `aaaa bbbb` alone, finds 9 columns, and keeps the
line — 13 columns wide:

```
printer                 printer_pp
f(aaaa                  f(aaaa bbbb))
  bbbb))
```

This accounts for 30 of the 32 divergences, and in every one of them
`printer_pp` is the one that overruns. There is no way to express it in the
library's API: it would need a "measure this, but render that", and `if_flat`
deliberately has no such thing.

### 2. Indentation is not capped

`printer` clamps every break indent to `width - 10`, so deeply nested code stops
marching toward the right margin. That clamp needs a column, and a `Doc` has no
columns until it is rendered: indentation there is a consequence of `horz` and
`vert`, decided during the render pass, not a number the builder ever holds.

At the `wasm-test-suite` block/loop tests — sixteen nested `do { ... }` — the
reference stacks everything at column 90 while `printer_pp` keeps indenting by
four and eventually breaks `do` away from its `{`. That is the whole of the
`indent` category, 2 files.

## Two more, not visible in the corpus

**Width is UTF-16 units.** `@pp` measures `txt` with `String::length`, and takes
no width hint. `printer` measures display width, so six CJK characters occupy
twelve columns there and six here, and `string_as` — which the colour themes use
to declare that an escape sequence occupies no columns — cannot be honoured at
all. The corpus is ASCII and `-f wax` is uncoloured, so neither shows up in the
numbers above; both are pinned as tests.

**Multi-line literals.** A block comment's content arrives as one `TText`
containing newlines. `printer` writes it through verbatim; `@pp.txt` rejects a
newline outright, so this package uses `txt_lines`, which stacks the lines with
`vert` and therefore re-indents the continuation lines to the ambient indent.

## How the lowering works

Three passes, in `doc.mbt` and `lower.mbt`:

1. **`tree`** rebuilds the bracketed structure the flat token stream encodes.
2. **`prune`** collapses runs of consecutive breaks. The streaming engine does
   this without meaning to — a break only sets `pend_line`, and nothing is
   written until the next *text* flushes it — so two breaks with no text between
   them, even in different groups, produce one line ending. A `Doc` has no such
   state, so it has to be done explicitly.
3. **`lay`** lowers to a `Doc`.

Two things in that lowering are worth knowing, because both are places the two
models genuinely disagree and the disagreement had to be resolved rather than
papered over.

### Where a collapsed run lands

The surviving break of a run decides what column the line lands at, and it is
not a free choice. The engine's `pend_line` indent is overwritten by *each*
break, so the line ends at the **last** break's indent — but a group opened
part-way through the run takes its base from `eff_col`, which reports the
*pending* indent, so it bases itself on the run so far.

`Pruner::settle` therefore keeps the last break when no group opened during the
run — exact, since every frame still open was opened before the run and sits at
the column `@pp` will render it at — and keeps the first, paying the indent
difference in literal spaces, when one did. Getting this wrong is expensive:
against the 32 files the rule above leaves, keeping the first unconditionally
leaves 66 and keeping the last unconditionally leaves 215.

### Indentation has to be spelled out

`@pp` has no indent operator. A group is joined to its left sibling with `horz`,
which is what rebases it to the column it opens at — the engine's `eff_col`
semantics, for free. Everything else is joined with `concat`, which leaves the
ambient indent alone, so a body's own breaks return to the group's base. A
`TNest` then has to be paid for in literal spaces written after each break
inside it.

## Cost

The dependency is a real one: `waxmb/wax` now pulls in
`marianoguerra/pretty-fast-pretty-printer` for every consumer, to support a
package the formatter does not use. `printer` remains the engine `@output.render`
and the CLI go through; nothing in the shipped path changed.
