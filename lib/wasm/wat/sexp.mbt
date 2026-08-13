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
  /// A node that owns a source span, so the comments written against it can be
  /// found. Carried as a wrapper rather than a field on every constructor:
  /// only some nodes come from somewhere, and the layout does not change.
  At(@basic.Location, Sexp)
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
    At(_, inner) => needs_vertical(inner)
    List(l) | Block(l, _, _) => l.iter().any(needs_vertical)
  }
}

///|
/// The indentation one level of nesting adds.
const INDENT : Int = 2

///|
/// Lay out a document at the width the reference uses.
///
/// TWO PASSES, as the Wax printer does and for the same reason: the first
/// records which spans the layout will actually look up, and `associate` then
/// attaches comments to exactly those. Attaching first would let a comment
/// land on a node this printer never reaches, and vanish.
pub fn render(
  s : Sexp,
  top_depth? : Int = 1,
  trivia? : @trivia.Context? = None,
) -> String {
  match trivia {
    None =>
      @printer.run_string(
        p => format(p, false, top_depth, false, s, Attach::plain()),
        width=78,
      )
    Some(tc) => {
      let (table, tail) = @trivia.associate(tc, only => {
        @printer.run_discard(p => {
          let dry = Attach::dry(only)
          format(p, false, top_depth, false, s, dry)
        })
      })
      @printer.run_string(
        p => {
          let ctx = Attach::of_table(table)
          format(p, false, top_depth, false, s, ctx)
          print_trivia(p, @trivia.drop_trailing_blank_lines(tail))
        },
        width=78,
      )
    }
  }
}

///|
/// What the layout needs to find the comments written against a span: either
/// the table that answers, or the set that is recording the questions.
priv struct Attach {
  table : @trivia.Table
  collect : @trivia.Locations?
}

///|
fn Attach::plain() -> Attach {
  { table: @trivia.Table::empty(), collect: None }
}

///|
fn Attach::dry(only : @trivia.Locations) -> Attach {
  { table: @trivia.Table::empty(), collect: Some(only) }
}

///|
fn Attach::of_table(table : @trivia.Table) -> Attach {
  { table, collect: None }
}

///|
/// Look up the trivia on a span, recording the lookup during the dry pass.
/// Every lookup goes through here, or the dry pass would not see it.
fn Attach::get(self : Attach, loc : @basic.Location) -> @trivia.Associated {
  match self.collect {
    Some(set) => {
      set.mark(loc)
      @trivia.empty_assoc
    }
    None => self.table.get(Some(loc))
  }
}

///|
/// Print a run of comments and blank lines.
///
/// A comment on its own line keeps one; one trailing a token is deferred past
/// the end of the line, so a separator printed after it still lands ahead of
/// it. The delimiters are the TEXT format's -- the source wrote `//` and this
/// is a wat file.
fn print_trivia(p : @printer.Printer, entries : Array[@trivia.Entry]) -> Unit {
  for e in entries {
    match (e.trivia, e.position) {
      (Item(content~, kind=BlockComment, ..), _) => {
        p.space()
        p.string(retarget(content, BlockComment))
        p.space()
      }
      (Item(content~, kind=LineComment, ..), Inline) =>
        p.defer_eol(() => {
          p.string(" ")
          p.string(retarget(content.trim().to_owned(), LineComment))
        })
      (Item(content~, kind=LineComment, ..), LineStart) => {
        p.newline()
        p.string(retarget(content.trim().to_owned(), LineComment))
        p.newline()
      }
      // An annotation is verbatim SOURCE text, and only the WebAssembly text
      // format has a syntax for one -- so it passes through as it stands.
      (Item(content~, kind=Annotation, ..), _) => {
        p.space()
        p.string(content)
        p.space()
      }
      (BlankLine, _) => p.blank_line()
    }
  }
}

///|
/// A comment as the WAT syntax writes it. Wax says `//` and `/* */`; wat says
/// `;;` and `(; ;)`, and the text is the same text.
fn retarget(content : String, kind : @trivia.TriviaKind) -> String {
  match kind {
    LineComment =>
      if content.has_prefix("//") {
        ";;" + content[2:].to_owned()
      } else {
        content
      }
    BlockComment => {
      let mut out = content
      if out.has_prefix("/*") {
        out = "(;" + out[2:].to_owned()
      }
      if out.has_suffix("*/") {
        out = out[:out.length() - 2].to_owned() + ";)"
      }
      out
    }
    Annotation => content
  }
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
  ctx : Attach,
  within? : Array[@trivia.Entry] = [],
) -> Unit {
  match s {
    // Its comments, then the node, then whatever trailed it. What is WITHIN
    // the node goes inside its parentheses, just before the closing one --
    // that is where a comment in an otherwise empty body belongs, and there is
    // nothing else for it to sit beside.
    At(loc, inner) => {
      let t = ctx.get(loc)
      print_trivia(p, t.before)
      format(p, in_block, depth, first, inner, ctx, within=t.within)
      print_trivia(p, t.after)
    }
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
                format(p, in_block, depth, i == 0, v, ctx)
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
              format(p, in_block, depth + 1, i == 0, v, ctx)
            }
          })
          p.cut()
          print_trivia(p, within)
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
          format(p, in_block || !transparent, depth, first && i == 0, v, ctx)
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
          format(p, in_block, depth, false, v, ctx)
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
              p.box(fn() { format(p, in_block, depth, false, d, ctx) })
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
                    format(p, in_block, depth, false, v, ctx)
                  }
                })
              })
          }
        }
      })
  }
}
