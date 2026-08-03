# printer_pp — the same documents, a different engine

`printer` is a streaming layout engine with bounded lookahead, ported from the
reference OCaml because byte-exact output is this project's whole point.
`printer_pp` answers the question that ports out of caution always leave open:
what would a general-purpose library have done instead?

The library is
[marianoguerra/pretty-fast-pretty-printer](https://mooncakes.io/docs/marianoguerra/pretty-fast-pretty-printer@0.2.0)
0.2.0, the MoonBit port of Brown PLT's `pretty-fast-pretty-printer`. It builds an
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
identical:       1901
differing:       2
agreement:       99%

  overflow (fit decision ignores trailing context): 0
  indent   (no max_indent cap):                     2
  other:                                            0
```

1901 of 1903 modules come out **byte for byte identical**. The two that do not
are the same difference, and it is the only one left.

## The difference that remains: indentation is not capped

`printer` clamps every break indent to `width - 10`, so deeply nested code stops
marching toward the right margin. That clamp needs a column, and a `Doc` has no
columns until it is rendered: indentation there is a consequence of `horz`,
`vert` and `nest`, decided during the render pass, not a number the builder ever
holds.

At the `wasm-test-suite` block and loop tests — sixteen nested `do { ... }` —
the reference stacks everything at column 90 while `printer_pp` keeps indenting
by four and eventually breaks `do` away from its `{`. Closing it would take a
`max_indent` render option in the library; nothing expressible in a document can
do it.

## What it took to get here

The first version of this package, against library 0.1.0, differed on 32 files.
Four of the five things that closed the gap are 0.2.0 API added in response to
this port; the fifth is a quirk of the reference that had to be modelled
deliberately.

**`if_flat`'s `reserve` — 30 files.** `if_flat` weighs its flat branch against
the space left on the line. The engine instead scans the token stream *past* the
end of the group, to the next break that would end the line, so the closing
`)`s and the trailing `;` count against it. `reserve` is how a caller states
that trailing width. Computing it is what `suffix` and `after` do in
`lower.mbt`: the rest of the group's own segment, plus — recursively — what the
enclosing body still has to fit, which is nothing at all unless the group ends
it, because in a breaking mode the scan stops at the very next break.

**`txt_as` — width.** `txt` measures UTF-16 code units. The builder measures
display width, so a CJK character is two columns and a colour escape is none.
The token stream carries the builder's number and `txt_as` states it, which is
why a coloured render now breaks in exactly the same places as an uncoloured
one.

**`txt_raw` — block comments.** A comment's content arrives as one `TText` with
newlines in it. The engine writes it through verbatim; `txt_lines` would stack
the lines with `vert` and re-indent the continuations.

**`Doc::flat_width` and `nest`.** The first replaced a parallel
re-implementation of the width the library already caches. The second models the
`eff_col` quirk below without moving the line the group starts on.

**If-broken content is rendered but never measured.** The engine's scan drops
the whole `TIfBroken` subtree, so the trailing comma a list grows when it breaks
must not be what tips it into breaking. Atoms carry a `hidden` flag for it.

**A flat `cut` still costs a column.** `eff_col` adds one for *any* pending flat
separator, while only `flush` looks at the strength — so a `cut`, which prints
nothing, still moves the base of a group opening right after it. That base
decides both the fit test and the indent, so it is a `reserve` of one plus a
`nest` of one. It is worth being precise about the scope: the shift applies to
that one group and does not accumulate down the nesting, because the engine
bases every group on the real column it prints at. Propagating it was worth
seven files in the wrong direction before that was fixed.

## How the lowering works

Three passes, in `doc.mbt` and `lower.mbt`:

1. **`tree`** rebuilds the bracketed structure the flat token stream encodes.
2. **`prune`** collapses runs of consecutive breaks. The streaming engine does
   this without meaning to — a break only sets `pend_line`, and nothing is
   written until the next *text* flushes it — so two breaks with no text between
   them, even in different groups, produce one line ending. A `Doc` has no such
   state, so it has to be done explicitly.
3. **`lay`** lowers to a `Doc`.

Three things in that lowering are worth knowing.

### Where a collapsed run lands

The surviving break of a run decides what column the line lands at, and it is
not a free choice. The engine's `pend_line` indent is overwritten by *each*
break, so the line ends at the **last** break's indent — but a group opened
part-way through the run takes its base from `eff_col`, which reports the
*pending* indent, so it bases itself on the run so far.

`Pruner::settle` therefore keeps the last break when no group opened during the
run — exact, since every frame still open was opened before the run and sits at
the column `@pp` will render it at — and keeps the first, paying the indent
difference in literal spaces, when one did.

Keeping the first unconditionally costs 202 files. Keeping the last
unconditionally costs none — this corpus never opens a group inside a run — but
it is wrong all the same, by one column per nested indent, and
`printer_pp_test.mbt` pins the shape that shows it.

### Indentation has to be spelled out

A group is joined to its left sibling with `horz2`, which is what rebases it to
the column it opens at — the engine's `eff_col` semantics, for free. Everything
else is joined with `concat2`, which leaves the ambient indent alone, so a
body's own breaks return to the group's base. A `TNest` is then paid for in
literal spaces written after each break inside it: `nest` wraps a whole
document, and a nest has to interleave with the body's own breaks.

### Both branches, built once

A group the engine keeps on one line still resolves the groups *inside* it one
at a time, and one of them can break anyway — so the flat branch of an `if_flat`
is the body laid out in Flat *mode*, not the body flattened outright. That means
every `GHv` materialises its body twice, and a document nested `d` groups deep
would cost `2^d`. `Memo` keys a built document on the group's identity, the mode
and the reserve, which turns the tree back into a DAG; the corpus run is about
ten seconds either way.

## Cost

The dependency is a real one: `waxmb/wax` pulls in
`marianoguerra/pretty-fast-pretty-printer` for every consumer, to support a
package the formatter does not use. `printer` remains the engine
`@output.render` and the CLI go through; nothing in the shipped path changed.
