// The machine-applicable simplifications offered to hand-written Wax.
//
// Ported from wax/src/lib-wax/typing_suggest.ml, and from the part of the
// reference's "keep-bool" machinery (typing.ml) that decides whether an
// annotation is load-bearing.
//
// Each is a `Suggestion` diagnostic carrying the rewrite as an edit, made only
// under `ModuleContext::suggest` -- which `wax check` sets -- and shown only
// where the warning policy enables it. The AST keeps no span for a type
// annotation, so the spans are recovered from the source text, with every scan
// bailing out rather than producing a wrong edit.

///|
/// What an unannotated binding -- `let x = <node>` -- would re-infer a checked
/// node to be: the question that decides whether its annotation is needed.
enum Reinfer {
  /// Delivers no value: a `br`, `return` or `unreachable` tail.
  Diverges
  /// Cannot be typed without the annotation: a construction whose type name is
  /// not written, say.
  Uninferrable
  /// Re-infers to this type, standalone, and may be narrowed to it.
  Typ(@infer.Cell[@infer.InferredType])
  /// Re-infers to this type through a name it writes, so only an annotation
  /// EQUAL to it is redundant.
  Named(@infer.Cell[@infer.InferredType])
}

///|
/// A snapshot of a cell, so later unification does not reach it.
fn reinfer_of_cell(c : @infer.Cell[@infer.InferredType]) -> Reinfer {
  Typ(@infer.Cell::make(c.get()))
}

///|
fn named_reinfer_of_cell(c : @infer.Cell[@infer.InferredType]) -> Reinfer {
  Named(@infer.Cell::make(c.get()))
}

///|
/// Whether two value types are the same type: each a subtype of the other.
fn valtype_equal(
  ctx : @typing_env.ModuleContext,
  a : @infer.InferredValType,
  b : @infer.InferredValType,
) -> Bool {
  let info = ctx.type_context.subtyping_info()
  @type_store.val_subtype(info, a.internal, b.internal) &&
  @type_store.val_subtype(info, b.internal, a.internal)
}

///|
/// Whether an annotation is load-bearing: unless the value's own standalone
/// type already equals it -- or, for an immutable binding (`drop_supertype`),
/// is a subtype of it -- dropping it would change the program. A bottom
/// reference (a bare `null`'s `&?none`) is never a useful narrowing.
fn annotation_needed(
  ctx : @typing_env.ModuleContext,
  standalone : @infer.InferredValType?,
  expected : @infer.Cell[@infer.InferredType],
  drop_supertype~ : Bool = false,
) -> Bool {
  match (standalone, expected.get()) {
    (Some(v), Valtype(b)) => {
      let bottom = v.typ
        is Ref({ typ: None_ | NoFunc | NoExtern | NoExn | NoCont, .. })
      if drop_supertype && !bottom {
        !@type_store.val_subtype(
          ctx.type_context.subtyping_info(),
          v.internal,
          b.internal,
        )
      } else {
        !valtype_equal(ctx, v, b)
      }
    }
    _ => true
  }
}

///|
/// `annotation_needed`, for what a node re-infers to.
fn reinfer_needed(
  ctx : @typing_env.ModuleContext,
  reinfer : Reinfer,
  expected : @infer.Cell[@infer.InferredType],
  drop_supertype~ : Bool = false,
) -> Bool {
  match reinfer {
    Diverges | Uninferrable => true
    Typ(c) =>
      annotation_needed(
        ctx,
        @typing_env.standalone_valtype(c),
        expected,
        drop_supertype~,
      )
    Named(c) =>
      annotation_needed(ctx, @typing_env.standalone_valtype(c), expected)
  }
}

///|
/// Whether a block's declared result equals the type its context already pins,
/// so a re-parse recovers it from there.
fn block_result_redundant(
  typ : @ast.FuncType,
  expected : @infer.Cell[@infer.InferredType],
  result_cell : @infer.Cell[@infer.InferredType],
  ctx : @typing_env.ModuleContext,
) -> Bool {
  typ.results.length() > 0 &&
  !typ.results.iter().any(t => t is Alias(_)) &&
  (match
    (
      @typing_env.standalone_valtype(expected),
      @typing_env.standalone_valtype(result_cell),
    ) {
    (Some(a), Some(b)) => valtype_equal(ctx, a, b)
    _ => false
  })
}

///|
/// The source between two offsets, if there is source and they lie in it.
fn source_between(
  ctx : @typing_env.ModuleContext,
  start : Int32,
  end : Int32,
) -> String? {
  guard ctx.diagnostics.source() is Some(src) else { return None }
  guard start >= 0 && start <= end && end <= src.length() else { return None }
  Some(src[start:end].to_owned())
}

///|
/// The same text with each comment's contents replaced by spaces, so a `:` or
/// a terminator inside one is not mistaken for code. Lengths are kept, so an
/// offset in the result is an offset in the original.
fn blank_comments(s : String) -> String {
  let out = StringBuilder()
  let n = s.length()
  let mut i = 0
  while i < n {
    if i + 1 < n && s[i] == '/' && s[i + 1] == '/' {
      while i < n && s[i] != '\n' {
        out.write_char(' ')
        i = i + 1
      }
    } else if i + 1 < n && s[i] == '/' && s[i + 1] == '*' {
      out.write_string("  ")
      i = i + 2
      while i < n && !(i + 1 < n && s[i] == '*' && s[i + 1] == '/') {
        out.write_char(if s[i] == '\n' { '\n' } else { ' ' })
        i = i + 1
      }
      if i < n {
        out.write_string("  ")
        i = i + 2
      }
    } else {
      out.write_char(s[i].unsafe_to_char())
      i = i + 1
    }
  }
  out.to_string()
}

///|
/// A span from one position to `start + k` and `start + l`, on its line.
fn offset_span(
  at : @basic.Position,
  from : Int32,
  to : Int32,
) -> @basic.Location {
  {
    start: { ..at, cnum: at.cnum + from, },
    end: { ..at, cnum: at.cnum + to, },
  }
}

///|
/// Report a suggestion: severity `Suggestion`, the rewrite as its edit, made
/// once whatever the configuration, and not while recovering from errors.
fn suggest(
  ctx : @typing_env.ModuleContext,
  warning : @warning.Warning,
  edit_loc : @basic.Location,
  new_text : String,
  location : @basic.Location,
  message : String,
) -> Unit {
  guard !ctx.diagnostics.in_recovery() else { return }
  ctx.diagnostics.report(
    location,
    Suggestion,
    @message.text(message),
    warning=Some(warning),
    universal=true,
    edit=Some({ loc: edit_loc, new_text, }),
  )
}

///|
/// The `: t` annotation between a binding name's end and the boundary after
/// it: the type's own span, to underline, and the `: t` span, to delete. `None`
/// when it spans lines or cannot be isolated.
fn annotation_spans(
  ctx : @typing_env.ModuleContext,
  name_end : @basic.Position,
  boundary : @basic.Position,
) -> (@basic.Location, @basic.Location)? {
  guard name_end.lnum == boundary.lnum else { return None }
  guard source_between(ctx, name_end.cnum, boundary.cnum) is Some(gap) else {
    return None
  }
  let gap = blank_comments(gap)
  let n = gap.length()
  let mut colon = -1
  for k in 0..<n {
    if gap[k] == ':' {
      colon = k
      break
    }
  }
  guard colon >= 0 else { return None }
  let mut stop = n
  for k in (colon + 1)..<n {
    if gap[k] is (')' | ']' | ',' | '=' | ';') {
      stop = k
      break
    }
  }
  let mut s = colon + 1
  let mut e = stop
  while s < e && gap[s] is (' ' | '\t') {
    s = s + 1
  }
  while e > s && gap[e - 1] is (' ' | '\t') {
    e = e - 1
  }
  guard s < e else { return None }
  Some((offset_span(name_end, s, e), offset_span(name_end, colon, e)))
}

///|
/// Offer dropping a binding's redundant `: t`.
fn suggest_redundant_annotation(
  ctx : @typing_env.ModuleContext,
  name_end : @basic.Position,
  boundary : @basic.Position,
) -> Unit {
  guard annotation_spans(ctx, name_end, boundary) is Some((type_span, delete)) else {
    return
  }
  suggest(
    ctx,
    RedundantAnnotation,
    delete,
    "",
    type_span,
    "This type annotation is redundant; the initializer's type is inferred.",
  )
}

///|
/// Offer `x op= e` for `x = x op e`, spliced from the source so spacing and
/// comments in `e` are kept.
fn suggest_compound_assignment(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  target : @ast.Ident,
  value : @ast.Instr[@basic.Location],
) -> Unit {
  guard value.desc is BinOpI(op, lhs, rhs) else { return }
  guard op.desc
    is (Add | Sub | Mul | Div(_) | Rem(_) | And | Or | Xor | Shl | Shr(_)) else {
    return
  }
  guard lhs.desc is Get(g) && g.name == target.name else { return }
  guard source_between(ctx, target.loc.start.cnum, target.loc.end.cnum)
    is Some(t) &&
    source_between(ctx, op.info.start.cnum, op.info.end.cnum) is Some(o) &&
    source_between(ctx, rhs.info.start.cnum, rhs.info.end.cnum) is Some(r) else {
    return
  }
  suggest(
    ctx,
    CompoundAssignment,
    location,
    "\{t} \{o}= \{r}",
    location,
    "This assignment can use the compound form '\{t} \{o}= …'.",
  )
}

///|
/// Offer the shorthand `{x}` for a field written `x: x`.
fn suggest_punning(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
  written : @ast.Instr[@basic.Location]?,
) -> Unit {
  guard written is Some({ desc: Get(g), info, .. }) && g.name == name.name else {
    return
  }
  suggest(
    ctx,
    FieldPunning,
    { start: name.loc.end, end: info.end, },
    "",
    name.loc,
    "This field can use the punning shorthand '\{name.name}'.",
  )
}

///|
/// Offer dropping a construction's redundant type name, `T|` included.
fn suggest_drop_type_name(
  ctx : @typing_env.ModuleContext,
  name : @ast.Ident,
) -> Unit {
  guard ctx.diagnostics.source() is Some(src) else { return }
  let n = src.length()
  let mut k = name.loc.end.cnum
  while k < n && src[k] is (' ' | '\t') {
    k = k + 1
  }
  guard k < n && src[k] == '|' else { return }
  suggest(
    ctx,
    RedundantAnnotation,
    { start: name.loc.start, end: { ..name.loc.end, cnum: k + 1, }, },
    "",
    name.loc,
    "This type name is redundant; it is inferred here.",
  )
}

///|
/// Offer dropping a block's redundant result type -- the `t` of `do t {` --
/// found as the text between its keyword and the brace.
fn suggest_block_result(
  ctx : @typing_env.ModuleContext,
  keyword : String,
  block_start : @basic.Position,
  brace_start : @basic.Position,
) -> Unit {
  guard block_start.lnum == brace_start.lnum else { return }
  guard source_between(ctx, block_start.cnum, brace_start.cnum) is Some(prefix) else {
    return
  }
  let prefix = blank_comments(prefix)
  fn is_id(c : UInt16) -> Bool {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
  }

  let m = keyword.length()
  let n = prefix.length()
  let mut at = -1
  for k in 0..<(n - m + 1) {
    let word = StringBuilder()
    for j in k..<(k + m) {
      word.write_char(prefix[j].unsafe_to_char())
    }
    if word.to_string() == keyword &&
      (k == 0 || !is_id(prefix[k - 1])) &&
      (k + m == n || !is_id(prefix[k + m])) {
      at = k
      break
    }
  }
  guard at >= 0 else { return }
  let mut s = at + m
  let mut e = n
  while s < n && prefix[s] is (' ' | '\t') {
    s = s + 1
  }
  while e > s && prefix[e - 1] is (' ' | '\t') {
    e = e - 1
  }
  guard s < e else { return }
  let span = offset_span(block_start, s, e)
  suggest(
    ctx,
    RedundantAnnotation,
    span,
    "",
    span,
    "This result type is redundant; it is inferred from the context.",
  )
}

///|
/// Offer dropping an `if`'s redundant `=> t`, found between the condition and
/// the brace.
fn suggest_if_result(
  ctx : @typing_env.ModuleContext,
  cond_end : @basic.Position,
  brace_start : @basic.Position,
) -> Unit {
  guard cond_end.lnum == brace_start.lnum else { return }
  guard source_between(ctx, cond_end.cnum, brace_start.cnum) is Some(gap) else {
    return
  }
  let gap = blank_comments(gap)
  let n = gap.length()
  let mut arrow = -1
  for k in 0..<(n - 1) {
    if gap[k] == '=' && gap[k + 1] == '>' {
      arrow = k
      break
    }
  }
  guard arrow >= 0 else { return }
  let mut s = arrow + 2
  let mut e = n
  while s < n && gap[s] is (' ' | '\t') {
    s = s + 1
  }
  while e > s && gap[e - 1] is (' ' | '\t') {
    e = e - 1
  }
  guard s < e else { return }
  suggest(
    ctx,
    RedundantAnnotation,
    offset_span(cond_end, arrow, e),
    "",
    offset_span(cond_end, s, e),
    "This result type is redundant; it is inferred from the context.",
  )
}

///|
/// Join two branches' re-inference: a diverging one drops out, an uninferrable
/// one poisons the whole, and two typed ones join as their values do -- `Named`
/// when either is.
fn join_reinfer(
  ctx : @typing_env.ModuleContext,
  a : Reinfer,
  b : Reinfer,
) -> Reinfer {
  match (a, b) {
    (Diverges, x) | (x, Diverges) => x
    (Uninferrable, _) | (_, Uninferrable) => Uninferrable
    (Typ(ta) | Named(ta), Typ(tb) | Named(tb)) => {
      let named = a is Named(_) || b is Named(_)
      match
        join_value_types(
          ta,
          tb,
          inferred_lub(ctx.type_context, ctx.diagnostics),
        ) {
        Some(c) => if named { Named(c) } else { Typ(c) }
        None => Uninferrable
      }
    }
  }
}

///|
/// What a node checked or synthesized as a leaf re-infers to: its own type,
/// snapshotted -- except a construction, which re-infers only through a name it
/// writes, or through fields that name exactly one type.
fn Checker::leaf_reinfer(
  self : Checker,
  c : @ast.Instr[@typing_env.InferredAnnotation],
  name_written~ : Bool = true,
) -> Reinfer {
  guard c.info.0 is [cell] else { return Uninferrable }
  match c.desc {
    Struct(_, fields) => {
      let by_fields = infer_struct_by_fields(self.ctx, fields.map(f => f.0))
      match (by_fields, @typing_env.standalone_valtype(cell)) {
        (Some(n), Some({ typ: Ref({ typ: Type(t) | Exact(t), .. }), .. })) if t.name ==
          n.name => reinfer_of_cell(cell)
        _ => Uninferrable
      }
    }
    Array(name, _, _)
    | ArrayDefault(name, _)
    | ArrayFixed(name, _)
    | ArraySegment(name, _, _, _)
    | StructDefault(name) =>
      if name_written && name is Some(_) {
        named_reinfer_of_cell(cell)
      } else {
        Uninferrable
      }
    _ => reinfer_of_cell(cell)
  }
}

///|
/// The names a body assigns, `x = e` or `x := e`: a binding none of them writes
/// is effectively immutable, and may drop an annotation that is a mere
/// supertype of its initializer's type.
fn collect_assigned_locals(
  instrs : Array[@ast.Instr[@basic.Location]],
) -> Map[String, Unit] {
  let out : Map[String, Unit] = Map([])
  fn go(i : @ast.Instr[@basic.Location]) -> Unit {
    match i.desc {
      Set(id, _, _) | Tee(id, _) => out[id.name] = ()
      _ => ()
    }
    for x in i.sub_instrs() {
      go(x)
    }
  }

  for i in instrs {
    go(i)
  }
  out
}
