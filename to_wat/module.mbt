// The module, as the text format writes it.
//
// No `(module ...)` wrapper unless the module is named: the reference lays an
// unnamed one out as its FIELDS, one per line, because that is what a wax
// module converts to -- a list of them, not a nested document.

///|
/// Print a module's text form.
pub fn print_module(
  m : @wasm_bin.Module,
  trivia? : @trivia.Context? = None,
) -> String raise WatError {
  // Each field with where it was written: the comments written against it are
  // found by that, and so is the conditional branch it stood in.
  let written : Array[(Sexp, @basic.Location)] = []
  let kinds : Array[FieldKind] = []
  for k, f in m.text.field_order {
    kinds.push(field_kind(f))
    let one = field(m, f)
    let loc = if k < m.text.field_locs.length() {
      m.text.field_locs[k]
    } else {
      @basic.dummy_loc
    }
    written.push((if loc.is_dummy() { one } else { At(loc, one) }, loc))
  }
  let fields = regroup(m.text.conditionals, written, kinds~)
  // A type nothing declared is NOT written. The section holds every signature
  // the lowering interned -- a block's, an import's, a `call_indirect`'s --
  // and the text format spells all of those inline where they are used. Only a
  // type the source wrote down is a field.
  //
  // The element segments minted to declare function references are different:
  // there is nowhere else to put a declarative segment, so it follows the
  // fields that were written.
  // A type the source did not write but that carries a NAME was materialised
  // for that name -- the entry exists for it alone -- so the text writes it.
  let placed_types : Map[Int, Bool] = Map([])
  for f in m.text.field_order {
    if f is FTypes(ks) {
      for k in ks {
        placed_types[k] = true
      }
    }
  }
  for k in 0..<m.types.length() {
    if !placed_types.contains(k) &&
      !m.text.signature_types.contains(k) &&
      m.names.types.contains(k) {
      fields.push(subtype_field(m, k))
    }
  }
  let placed_elems : Map[Int, Bool] = Map([])
  for f in m.text.field_order {
    if f is FElem(k) {
      placed_elems[k] = true
    }
  }
  for k in 0..<m.elems.length() {
    if !placed_elems.contains(k) {
      fields.push(elem_field(m, k))
    }
  }
  // A NAMED module keeps its wrapper, and then its fields are one level deeper
  // -- which is what makes them pack rather than each claim its own block.
  match m.names.module_ {
    Some(n) => {
      let l : Array[Sexp] = [
        Block([Atom("module"), Atom(ident(n))], KBox, true),
      ]
      for f in fields {
        l.push(f)
      }
      render(List(l), top_depth=0, trivia~) + "\n"
    }
    None => render(VBlock(fields), trivia~) + "\n"
  }
}

///|
/// A field's guard path: the conditional frames it was written inside,
/// outermost first. Each frame is a group and which branch of it.
fn guards_of(
  conds : Array[@wasm_bin.CondGroup],
  loc : @basic.Location,
) -> Array[(Int, Bool)] {
  fn covers(outer : @basic.Location, inner : @basic.Location) -> Bool {
    inner.start.cnum >= outer.start.cnum && inner.end.cnum <= outer.end.cnum
  }

  let out : Array[(Int, Bool)] = []
  for k, c in conds {
    if covers(c.then_, loc) {
      out.push((k, true))
    } else if c.else_ is Some(e) && covers(e, loc) {
      out.push((k, false))
    }
  }
  // Outermost first: an enclosing group starts before the ones inside it.
  out.sort_by((a, b) => conds[a.0].loc.start.cnum - conds[b.0].loc.start.cnum)
  out
}

///|
/// Whether two guard paths can never both hold.
///
/// Read in lockstep from the root: at the first frame where the CONDITIONS
/// agree and the branches do not, the two leaves are on opposite sides of one
/// question and never coexist. Once the conditions differ the leaves are in
/// unrelated subtrees and nothing deeper is shared, so this is not
/// satisfiability -- `debug` and `not(debug)` count as independent -- it only
/// keeps one branch's definition from counting against the other branch's
/// import.
fn mutually_exclusive(
  conds : Array[@wasm_bin.CondGroup],
  g1 : Array[(Int, Bool)],
  g2 : Array[(Int, Bool)],
) -> Bool {
  let n = if g1.length() < g2.length() { g1.length() } else { g2.length() }
  for k in 0..<n {
    if conds[g1[k].0].cond != conds[g2[k].0].cond {
      return false
    }
    if g1[k].1 != g2[k].1 {
      return true
    }
  }
  false
}

///|
/// Put the fields back under the conditionals they were written in, hoisting
/// the imports ahead of the definitions when one would otherwise follow one.
///
/// The checker flattens a conditional away, so both branches' fields are
/// already in the module and side by side; only where each STOOD says which
/// branch it came from. Each field's guard path says that, and consecutive
/// fields sharing a path are what one `(@if ..)` holds.
///
/// The hoist is what makes the guard path the right shape to group by rather
/// than containment: wasm requires every import before every definition, and a
/// conditional can put one after the other. Moving them is a no-op unless some
/// import really does follow a definition it is not mutually exclusive with,
/// which keeps every module that already validated byte-identical.
fn regroup(
  conds : Array[@wasm_bin.CondGroup],
  items : Array[(Sexp, @basic.Location)],
  kinds? : Array[FieldKind] = [],
  outer? : Array[(Int, Bool)] = [],
) -> Array[Sexp] {
  if conds.is_empty() {
    return items.map(i => i.0)
  }
  // The frames an ENCLOSING level already wrote are not written again here.
  // A `#[if]` holding one block holds everything in that block too, and
  // wrapping at both levels says it twice.
  let paths = items.map(i => {
    let g = guards_of(conds, i.1)
    if g.length() <= outer.length() {
      []
    } else {
      g[outer.length():].to_owned()
    }
  })
  let order = Array::makei(items.length(), k => k)
  if needs_reorder(conds, kinds, paths) {
    let imports = order.filter(k => k < kinds.length() && kinds[k] is KImport)
    let others = order.filter(k => !(k < kinds.length() && kinds[k] is KImport))
    order.clear()
    for k in imports {
      order.push(k)
    }
    for k in others {
      order.push(k)
    }
  }
  build(conds, items, paths, order, 0, 0, order.length())
}

///|
/// Whether any import is written after a definition it could coexist with.
fn needs_reorder(
  conds : Array[@wasm_bin.CondGroup],
  kinds : Array[FieldKind],
  paths : Array[Array[(Int, Bool)]],
) -> Bool {
  let defs : Array[Array[(Int, Bool)]] = []
  for k in 0..<paths.length() {
    guard k < kinds.length() else { continue }
    match kinds[k] {
      KImport =>
        for d in defs {
          if !mutually_exclusive(conds, d, paths[k]) {
            return true
          }
        }
      KDefine => defs.push(paths[k])
      KOther => ()
    }
  }
  false
}

///|
/// Build the fields at one guard depth: a run sharing a frame becomes one
/// `(@if ..)`, and a `then` run immediately followed by the matching `else`
/// run becomes the two-clause form they were written as.
fn build(
  conds : Array[@wasm_bin.CondGroup],
  items : Array[(Sexp, @basic.Location)],
  paths : Array[Array[(Int, Bool)]],
  order : Array[Int],
  depth : Int,
  from : Int,
  to : Int,
) -> Array[Sexp] {
  let out : Array[Sexp] = []
  let mut i = from
  while i < to {
    let g = paths[order[i]]
    if g.length() <= depth {
      out.push(items[order[i]].0)
      i = i + 1
      continue
    }
    let frame = g[depth]
    let mut j = i
    while j < to &&
          paths[order[j]].length() > depth &&
          paths[order[j]][depth] == frame {
      j = j + 1
    }
    let inner = build(conds, items, paths, order, depth + 1, i, j)
    // The other branch of the same group, if it is the very next run: that is
    // the shape it was written in, and splitting it would say the same thing
    // twice.
    let mut k = j
    let mut other : Array[Sexp] = []
    if frame.1 && j < to && paths[order[j]].length() > depth {
      let next = paths[order[j]][depth]
      if next.0 == frame.0 && !next.1 {
        while k < to &&
              paths[order[k]].length() > depth &&
              paths[order[k]][depth] == next {
          k = k + 1
        }
        other = build(conds, items, paths, order, depth + 1, j, k)
      }
    }
    if other.is_empty() && k == j {
      out.push(
        if frame.1 {
          cond_field(conds[frame.0], inner, [])
        } else {
          cond_else_only(conds[frame.0], inner)
        },
      )
      i = j
    } else {
      out.push(cond_field(conds[frame.0], inner, other))
      i = k
    }
  }
  out
}

///|
/// `(@if $c (@then) (@else ...))` -- an else run with no then beside it.
fn cond_else_only(c : @wasm_bin.CondGroup, else_ : Array[Sexp]) -> Sexp {
  At(
    c.loc,
    List([
      block([Atom("@if"), Atom(c.cond)]),
      List([Atom("@then")]),
      List([Atom("@else"), ..else_]),
    ]),
  )
}

///|
/// `(@if $cond (@then ...) (@else ...))`.
fn cond_field(
  c : @wasm_bin.CondGroup,
  then_ : Array[Sexp],
  else_ : Array[Sexp],
) -> Sexp {
  let l : Array[Sexp] = [block([Atom("@if"), Atom(c.cond)])]
  l.push(List([Atom("@then"), ..then_]))
  if !else_.is_empty() {
    l.push(List([Atom("@else"), ..else_]))
  }
  At(c.loc, List(l))
}

///|
/// What a field is, for the import hoist.
priv enum FieldKind {
  KImport
  KDefine
  KOther
}

///|
fn field_kind(f : @wasm_bin.FieldRef) -> FieldKind {
  match f {
    FImport(_) => KImport
    // What wasm requires an import to precede.
    FFunc(_) | FMemory(_) | FTable(_) | FTag(_) | FGlobal(_) => KDefine
    _ => KOther
  }
}

///|
/// One module field, written where the source put it.
fn field(m : @wasm_bin.Module, f : @wasm_bin.FieldRef) -> Sexp raise WatError {
  match f {
    // A `rec` group is one field holding several definitions; a lone type is
    // written bare, because a singleton `rec` is a DIFFERENT type and the
    // source said which it wrote.
    FTypes([k]) => subtype_field(m, k)
    FTypes(ks) => {
      let l : Array[Sexp] = [Atom("rec")]
      for k in ks {
        l.push(subtype_field(m, k))
      }
      List(l)
    }
    FFeature(name) => List([Atom("@feature"), Atom(quoted(name))])
    FStart(f) => List([Atom("start"), Atom(name_or(m.names.functions, f))])
    FExport(k) => export_field(m, k)
    FImport(k) => import_field(m, k)
    FFunc(k) => function_field(m, k, m.codes[k])
    FTable(k) => table_field(m, k)
    FMemory(k) => memory_field(m, k)
    FGlobal(k) => global_field(m, k)
    FTag(k) => tag_field(m, k)
    FElem(k) => elem_field(m, k)
    FData(k) => data_field(m, k)
  }
}

///|
/// One function: its name, its inline signature, its locals, its body.
///
/// The signature is written INLINE -- `(param $x i32) (result i32)` -- rather
/// than as a type reference, which is what the reference does and what keeps
/// the text readable without the type section beside it.
fn function_field(
  m : @wasm_bin.Module,
  k : Int,
  code : @wasm_bin.FunctionCode,
) -> Sexp raise WatError {
  let index = k + imported_count(m, "func")
  let locals = m.names.locals.get(index).unwrap_or(Map([]))
  let ft = match m.types[m.funcs[k]].composite {
    Func(ft) => ft
    _ => raise NotPrinted("a function whose type is not a function type")
  }
  // The head -- name, exports, signature -- breaks as one group, so a long
  // signature wraps under the name rather than each clause taking a line.
  let head : Array[Sexp] = [
    Atom("func"),
    Atom(name_or(m.names.functions, index)),
  ]
  for e in export_clauses(m, Func(index)) {
    head.push(e)
  }
  // `fn f: ft(..)` named a type, and the text names it rather than repeating
  // the signature that declaration pointed at.
  let wrote = m.text.decl_typeuse.get(OwnerFunc(index))
  let by_name = wrote is Some({ named: true, .. })
  if by_name {
    head.push(List([Atom("type"), Atom(name_or(m.names.types, m.funcs[k]))]))
  }
  // The signature is a group of its own, so it moves to its own line as a
  // unit when the name and exports have already filled one -- rather than the
  // first few parameters trailing the name and the rest wrapping.
  let sign : Array[Sexp] = []
  // All unnamed: ONE `(param i32 i32)` group. Any named: one group each,
  // because a name belongs to its own parameter and there is nowhere in the
  // shared form to put it.
  let mut any_named = false
  for p, _ in ft.params {
    if local_name(locals, p) != "" {
      any_named = true
    }
  }
  if by_name && !(wrote is Some({ spelled: true, .. })) {
    // Named and nothing else written: the signature is the type's, and
    // repeating it here would say the same thing twice.
    ()
  } else if any_named {
    for p, ty in ft.params {
      sign.push(
        List(
          named_type(local_name(locals, p), "param", valtype(ty, m.names.types)),
        ),
      )
    }
  } else if !ft.params.is_empty() {
    let g : Array[Sexp] = [Atom("param")]
    for ty in ft.params {
      g.push(Atom(valtype(ty, m.names.types)))
    }
    sign.push(List(g))
  }
  if (!by_name || wrote is Some({ spelled: true, .. })) &&
    !ft.results.is_empty() {
    let r : Array[Sexp] = [Atom("result")]
    for ty in ft.results {
      r.push(Atom(valtype(ty, m.names.types)))
    }
    sign.push(List(r))
  }
  if !sign.is_empty() {
    head.push(block(sign))
  }
  let out : Array[Sexp] = [block(head)]
  // The compilation hint belongs to the FUNCTION rather than to any
  // instruction, and the section keys it at offset zero -- which is why it is
  // written here, before the locals, rather than on the first statement.
  if code.priority is Some(p) {
    let l : Array[Sexp] = [
      Atom("@metadata.code.compilation_priority"),
      List([Atom("priority"), Atom(p.compilation.to_string())]),
    ]
    if p.optimization is Some(o) {
      // `run_once` is the reserved value, and prints as its keyword.
      l.push(
        if o == 127 {
          List([Atom("run_once")])
        } else {
          List([Atom("optimization"), Atom(o.to_string())])
        },
      )
    }
    out.push(List(l))
  }
  // The DECLARED locals follow the parameters in the same index space, so
  // their names are looked up past the parameter count. They pack onto as few
  // lines as they fit on, which is what `hov` means.
  if !code.locals.is_empty() {
    let l : Array[Sexp] = []
    for j, ty in code.locals {
      l.push(
        List(
          named_type(
            local_name(locals, ft.params.length() + j),
            "local",
            valtype(ty, m.names.types),
          ),
        ),
      )
    }
    out.push(Block(l, KHov, false))
  }
  let ctx = {
    m,
    locals,
    labels: m.names.labels.get(index).unwrap_or(Map([])),
    opened: 0,
    scope: [],
    conditionals: code.conditionals,
  }
  for
    st in statements(
      fold(code.body, code.spans, nested=code.nested_spans),
      ctx,
      code.conditionals,
    ) {
    out.push(st)
  }
  List(out)
}

///|
/// `(param $x i32)`, or `(param i32)` when nothing named it.
fn named_type(name : String, kind : String, ty : String) -> Array[Sexp] {
  if name == "" {
    [Atom(kind), Atom(ty)]
  } else {
    [Atom(kind), Atom(name), Atom(ty)]
  }
}

///|
/// A local's name, or nothing.
fn local_name(locals : Map[Int, Bytes], k : Int) -> String {
  match locals.get(k) {
    Some(b) => ident(b)
    None => ""
  }
}

///|
/// What printing one function body needs to know beyond the tree.
///
/// `opened` counts the blocks in the order they OPEN, which is the order the
/// name section numbers their labels in; `scope` is the same blocks stacked
/// innermost-last, which is what a branch depth counts against. The two differ
/// -- a name belongs to its block, a depth to where the branch stands -- so
/// both are carried.
priv struct Ctx {
  m : @wasm_bin.Module
  locals : Map[Int, Bytes]
  labels : Map[Int, Bytes]
  mut opened : Int
  scope : Array[String?]
  /// The `#[if(..)]` groups written in this body, for the statements at every
  /// level of it -- a conditional can hold a block whose body holds another.
  conditionals : Array[@wasm_bin.CondGroup]
}

///|
/// A run of statements, with the ones written inside a `#[if(..)]` put back
/// under it. Every level of a body goes through here: a conditional can sit
/// inside a block whose body has its own.
fn statements(
  nodes : Array[Node],
  ctx : Ctx,
  conds : Array[@wasm_bin.CondGroup],
  outer? : Array[(Int, Bool)] = [],
) -> Array[Sexp] raise WatError {
  let items : Array[(Sexp, @basic.Location)] = []
  for n in nodes {
    items.push((folded(n, ctx), n.loc))
  }
  regroup(conds, items, outer~)
}

///|
/// One folded instruction: `(head operand operand)`, or just `(head)` when it
/// takes none.
///
/// A structural instruction is written the same way, except that what follows
/// the head is the code it guards rather than values it consumes.
fn folded(node : Node, ctx : Ctx) -> Sexp raise WatError {
  let out = folded_bare(node, ctx)
  // Where the source wrote it, so a comment against it can be found. A node
  // no span covered was not written anywhere in particular.
  if node.loc.is_dummy() {
    out
  } else {
    At(node.loc, out)
  }
}

///|
fn folded_bare(node : Node, ctx : Ctx) -> Sexp raise WatError {
  // A string literal is written as one: the constants it lowered to are the
  // string, so writing both would say the same thing twice.
  if node.head is FromString(bytes, named, _) {
    // The type is written only when the SOURCE named one. Naming it whenever
    // the type HAS a name was measured and is much worse -- 1611 exact to
    // 1559 -- because most strings land in a named type the reference leaves
    // out, so which was written has to be recorded rather than inferred.
    let l : Array[Sexp] = [Atom("@string")]
    if named is Some(t) {
      l.push(Atom(name_or(ctx.m.names.types, t)))
    }
    l.push(Atom(quoted(bytes)))
    return List(l)
  }
  if node.head is FromChar(bytes, _) {
    return List([Atom("@char"), Atom(quoted(bytes))])
  }
  // A hinted instruction prints its annotations BEFORE itself, outside the
  // parentheses of the group it heads -- the hint is about the instruction,
  // not an operand of it. The wrapper is transparent so the annotation and
  // the group it labels break together.
  if node.head is Hinted(h, inner) {
    let annots = hint_annotations(h, ctx.m.names)
    if !annots.is_empty() {
      annots.push(folded({ ..node, head: inner }, ctx))
      return Block(annots, KBox, true)
    }
    return folded({ ..node, head: inner }, ctx)
  }
  if !node.bodies.is_empty() ||
    node.head is (Block(_, _) | Loop(_, _) | If(_, _, _)) {
    return structural(node, ctx)
  }
  // The head and its operands are ONE fill group, so they pack onto as many
  // lines as they need. They are not children of the list itself: those break
  // all together, which is right for a body's statements and wrong for a
  // folded instruction's operands.
  let head = mnemonic(node.head, ctx.m.names, ctx.locals, scope=ctx.scope)
  let l : Array[Sexp] = [head]
  for operand in node.operands {
    l.push(folded(operand, ctx))
  }
  List([Block(l, KBox, true)])
}

///|
/// `(block $l (result T) body...)`, and the two that shape their bodies
/// differently: `if`, whose operand comes before two named clauses.
fn structural(node : Node, ctx : Ctx) -> Sexp raise WatError {
  // The label is claimed BEFORE the body is printed, because that is the order
  // the blocks open in and so the order the names are numbered in.
  let opened = ctx.opened
  ctx.opened = opened + 1
  let name = match ctx.labels.get(opened) {
    Some(b) => Some(ident(b))
    None => None
  }
  let (word, bt) = match node.head {
    Block(bt, _) => ("block", bt)
    Loop(bt, _) => ("loop", bt)
    If(bt, _, _) => ("if", bt)
    TryTable(bt, _, _) => ("try_table", bt)
    LegacyTry(bt, _, _, _) => ("try", bt)
    _ => raise NotPrinted(constructor_of(node.head))
  }
  let head : Array[Sexp] = [Atom(word)]
  if name is Some(n) {
    head.push(Atom(n))
  }
  for t in blocktype(bt, ctx.m) {
    head.push(t)
  }
  // The `if` condition is an operand, so it joins the head's group; the
  // clauses that follow are list children and break onto their own lines.
  let l : Array[Sexp] = if node.operands.is_empty() {
    [block(head)]
  } else {
    let g : Array[Sexp] = [block(head)]
    for operand in node.operands {
      g.push(folded(operand, ctx))
    }
    [Block(g, KBox, true)]
  }
  // A `try_table`'s handlers are IMMEDIATES that branch OUT of it, so their
  // labels are read in the enclosing scope -- the try_table's own label is in
  // scope for its body and not for its handlers. Resolved before the push, not
  // after, or every handler names one block too deep.
  if node.head is TryTable(_, handlers, _) {
    let hs : Array[Sexp] = []
    for h in handlers {
      hs.push(catch_clause(h, ctx))
    }
    l.push(block(hs))
  }
  ctx.scope.push(name)
  // The legacy `try`'s handlers are inline BODIES that run in place, so each
  // is a named clause around the code it guards.
  let clauses = match node.head {
    If(_, _, _) => ["then", "else"]
    LegacyTry(_, _, catches, all) => {
      let names : Array[String] = ["do"]
      for c in catches {
        names.push("catch " + name_or(ctx.m.names.tags, c.0))
      }
      if all is Some(_) {
        names.push("catch_all")
      }
      names
    }
    _ => []
  }
  for j, body in node.bodies {
    let inner = statements(
      body,
      ctx,
      ctx.conditionals,
      outer=guards_of(ctx.conditionals, node.loc),
    )
    if j < clauses.length() {
      // An `else` with nothing in it is not written. `then` always is, even
      // empty, because it is what the condition guards.
      if !(clauses[j] == "else" && inner.is_empty()) {
        let c : Array[Sexp] = [Atom(clauses[j])]
        for x in inner {
          c.push(x)
        }
        l.push(List(c))
      }
    } else {
      for x in inner {
        l.push(x)
      }
    }
  }
  let _ = ctx.scope.pop()
  List(l)
}

///|
/// What a block produces, when it produces anything.
fn blocktype(bt : @wasm_bin.BlockType, m : @wasm_bin.Module) -> Array[Sexp] {
  match bt {
    Empty => []
    Value(t) => [List([Atom("result"), Atom(valtype(t, m.names.types))])]
    MultiValue(ts) | InlineType([], ts) => {
      let out : Array[Sexp] = []
      for t in ts {
        out.push(List([Atom("result"), Atom(valtype(t, m.names.types))]))
      }
      out
    }
    // A block's signature is spelled OUT, parameters and all: the text format
    // lets a block carry a whole function type inline, so there is never a
    // need to name one. Naming it whenever the type HAD a name was measured
    // and is worse, and so was naming it as soon as the block consumed
    // anything.
    TypeIndex(k) => typeuse(m, k)
    InlineType(params, results) => {
      let out : Array[Sexp] = []
      let p : Array[Sexp] = [Atom("param")]
      for t in params {
        p.push(Atom(valtype(t, m.names.types)))
      }
      out.push(List(p))
      let r : Array[Sexp] = [Atom("result")]
      for t in results {
        r.push(Atom(valtype(t, m.names.types)))
      }
      out.push(List(r))
      out
    }
  }
}

///|
/// One `try_table` handler: which tag it catches and where it branches to.
fn catch_clause(h : @wasm_bin.CatchHandler, ctx : Ctx) -> Sexp {
  let tags = ctx.m.names.tags
  match h {
    Catch(t, l) =>
      List([Atom("catch"), Atom(name_or(tags, t)), Atom(label(ctx.scope, l))])
    CatchRef(t, l) =>
      List([
        Atom("catch_ref"),
        Atom(name_or(tags, t)),
        Atom(label(ctx.scope, l)),
      ])
    CatchAll(l) => List([Atom("catch_all"), Atom(label(ctx.scope, l))])
    CatchAllRef(l) => List([Atom("catch_all_ref"), Atom(label(ctx.scope, l))])
  }
}

///|
/// The `(@metadata.code.*)` annotations an instruction's hints print as, in
/// the order the sections carry them.
///
/// A hint has to round-trip EXACTLY -- it is a byte in a custom section, not
/// advice -- so each one prints in the structured form when that form can
/// name the same byte, and as the raw payload when it cannot.
fn hint_annotations(
  h : @wasm_bin.InstrHints,
  names : @wasm_bin.Names,
) -> Array[Sexp] {
  let out : Array[Sexp] = []
  if h.branch is Some(likely) {
    out.push(
      List([
        Atom("@metadata.code.branch_hint"),
        Atom(if likely { "\"\\01\"" } else { "\"\\00\"" }),
      ]),
    )
  }
  if h.freq is Some(b) {
    out.push(List([Atom("@metadata.code.instr_freq"), freq_payload(b)]))
  }
  if h.targets is Some(ts) {
    let l : Array[Sexp] = [Atom("@metadata.code.call_targets")]
    for t in ts {
      l.push(
        List([
          Atom("target"),
          Atom(name_or(names.functions, t.0)),
          Atom(percent(t.1)),
        ]),
      )
    }
    out.push(List(l))
  }
  out
}

///|
/// A frequency hint's payload. The two reserved bytes print as their keywords;
/// otherwise the byte stands for a base-2 executions-per-call ratio, written
/// as `(freq n)` when that ratio is a whole number -- the hot-instruction case
/// -- and as the raw byte when it is not, because a fractional ratio's
/// shortest decimal need not re-encode to the same byte.
fn freq_payload(b : Int) -> Sexp {
  if b == 0 {
    return List([Atom("never_opt")])
  }
  if b == 127 {
    return List([Atom("always_opt")])
  }
  if b >= 32 && b <= 64 {
    let mut r = 1L
    for _ in 0..<(b - 32) {
      r = r * 2L
    }
    return List([Atom("freq"), Atom(r.to_string())])
  }
  Atom("\"\\" + hex2(b & 0xFF) + "\"")
}

///|
/// A call-target share, as the fraction the annotation writes: `73` is `0.73`,
/// and a whole one is written without a point.
fn percent(pct : Int) -> String {
  if pct % 100 == 0 {
    return (pct / 100).to_string()
  }
  let whole = pct / 100
  let frac = pct % 100
  if frac % 10 == 0 {
    whole.to_string() + "." + (frac / 10).to_string()
  } else {
    whole.to_string() +
    "." +
    (if frac < 10 { "0" } else { "" }) +
    frac.to_string()
  }
}
