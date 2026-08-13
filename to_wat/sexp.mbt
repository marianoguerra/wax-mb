// The layout tree, and the engine that lays it out.
//
// Ported from the `sexp` type and `format_sexp` in wax/src/lib-wasm/output.ml.
//
// The printers build this rather than strings because where the lines break is
// not a property of any one field: `(func ...)` puts its closing paren on its
// own line when its body breaks and keeps it on the line when the whole thing
// fits, and that decision belongs to the pretty printer, which already exists
// in `printer/`. Deciding it inside each printer -- "does this fit in 80
// columns" -- gets the easy cases and none of the nested ones.

///|
/// How a `Block` packs its elements.
pub(all) enum BlockKind {
  /// Break all or nothing.
  KBox
  /// Fill the line, breaking only where it must.
  KHov
  /// Break every separator, or none.
  KHv
}

///|
/// A layout node.
pub(all) enum Sexp {
  Atom(String)
  /// A parenthesised group.
  List(Array[Sexp])
  /// A run of elements that is NOT parenthesised: a head and its immediates,
  /// which break together rather than each on its own line.
  Block(Array[Sexp], BlockKind, Bool)
  /// Elements strictly one per line.
  VBlock(Array[Sexp])
  /// A delimiter, then its indented contents, then the next delimiter -- the
  /// `block ... end` shape, which is a list of neither operands nor fields.
  SBlock(Array[Structure])
}

///|
pub(all) enum Structure {
  Delimiter(Sexp)
  Contents(Array[Sexp])
}

///|
/// A plain block: elements packed, breaking all together.
pub fn block(l : Array[Sexp]) -> Sexp {
  Block(l, KBox, false)
}

///|
/// Whether anything under here forces the vertical layout. A list holding a
/// `block ... end` cannot be packed onto one line, however short it is.
fn needs_vertical(s : Sexp) -> Bool {
  match s {
    VBlock(_) | SBlock(_) => true
    Atom(_) => false
    List(l) | Block(l, _, _) => l.iter().any(needs_vertical)
  }
}

///|
/// The indentation one level of nesting adds.
const INDENT : Int = 2

///|
/// Lay out a document at the width the reference uses.
pub fn render(s : Sexp, top_depth? : Int = 1) -> String {
  @printer.run_string(p => format(p, false, top_depth, false, s), width=78)
}

///|
/// Lay one node out.
///
/// `depth` is how deep in the tree this node sits, and it is what makes the
/// layout HYBRID: the top two levels -- the module's fields and their heads --
/// lay out with the closing paren on its own line when they break, and
/// everything below them packs. A body reads as a paragraph, a field reads as
/// a block.
///
/// `in_block` says whether an enclosing non-transparent `Block` already claimed
/// the indent, and `first` whether this is the head of one.
fn format(
  p : @printer.Printer,
  in_block : Bool,
  depth : Int,
  first : Bool,
  s : Sexp,
) -> Unit {
  match s {
    Atom(t) => p.string(t)
    List(l) =>
      if depth > 1 {
        p.box(fn() {
          p.string("(")
          p.hvbox(
            fn() {
              for i, v in l {
                if i > 0 {
                  p.space()
                }
                format(p, in_block, depth, i == 0, v)
              }
            },
            indent=INDENT - 1,
          )
          p.string(")")
        })
      } else {
        let vertical = l.iter().any(needs_vertical)
        let body = fn() {
          p.string("(")
          p.indent(INDENT, fn() {
            for i, v in l {
              if i > 0 {
                p.space()
              }
              format(p, in_block, depth + 1, i == 0, v)
            }
          })
          p.cut()
          p.box(fn() { p.string(")") })
        }
        if vertical {
          p.vbox(body)
        } else {
          p.hvbox(body)
        }
      }
    Block(l, bk, transparent) => {
      // The head of a group carries the opening paren, which is one column the
      // enclosing indent already spent -- so it indents one less.
      let indent = if first { INDENT - 1 } else { 0 }
      let render = fn() {
        for i, v in l {
          if i > 0 {
            p.space()
          }
          format(p, in_block || !transparent, depth, first && i == 0, v)
        }
      }
      match bk {
        KHv => p.hvbox(render, indent~)
        KHov => p.hovbox(render, indent~)
        KBox => p.box(render, indent~)
      }
    }
    VBlock(l) =>
      p.vbox(fn() {
        for i, v in l {
          if i > 0 {
            p.space()
          }
          format(p, in_block, depth, false, v)
        }
      })
    SBlock(l) =>
      p.vbox(fn() {
        for i, s in l {
          match s {
            Delimiter(d) => {
              if i > 0 {
                p.newline()
              }
              p.box(fn() { format(p, in_block, depth, false, d) })
            }
            Contents([]) => ()
            Contents(inner) =>
              p.indent(INDENT, fn() {
                p.newline()
                p.vbox(fn() {
                  for j, v in inner {
                    if j > 0 {
                      p.newline()
                    }
                    format(p, in_block, depth, false, v)
                  }
                })
              })
          }
        }
      })
  }
}
