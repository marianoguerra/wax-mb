// The checker's contexts: what is in scope while a module is being checked.
//
// Ported from wax/src/lib-wax/typing_env.ml. Two records, and the split between
// them is the module's shape: `TypeContext` is what resolving a TYPE needs, and
// `ModuleContext` is everything else -- which is to say, everything the
// instruction checker reads.

///|
/// The type-resolution context: the names in scope, the store they resolve
/// into, and the proposals that are enabled.
pub struct TypeContext {
  /// The interned store the resolved indices point into.
  store : @type_store.TypeStore
  /// Name to (index, definition), under the current branch assumption.
  types : Tbl[(@type_store.RefIndex, @ast.SubType)]
  features : @feature.Set
  /// Subtyping info for `store`, computed on demand and dropped whenever a type
  /// is added -- including a function type minted mid-check for an inline
  /// `&fn(..)` cast target -- so a query always sees the current type space.
  mut subtyping_cache : @type_store.SubtypingInfo?
}

///|
pub fn TypeContext::new(
  store : @type_store.TypeStore,
  types : Tbl[(@type_store.RefIndex, @ast.SubType)],
  features : @feature.Set,
) -> TypeContext {
  { store, types, features, subtyping_cache: None }
}

///|
/// Subtyping info for the current type space.
pub fn TypeContext::subtyping_info(
  self : TypeContext,
) -> @type_store.SubtypingInfo {
  match self.subtyping_cache {
    Some(i) => i
    None => {
      let i = self.store.subtyping_info()
      self.subtyping_cache = Some(i)
      i
    }
  }
}

///|
/// Note that the type space changed, so the next query recomputes.
pub fn TypeContext::invalidate(self : TypeContext) -> Unit {
  self.subtyping_cache = None
}

///|
/// A function's entry in the name table.
///
/// `None` is a POISON entry: a function whose signature failed to resolve. The
/// name stays bound so its uses do not cascade into unbound-name reports,
/// mirroring the wasm validator's poisoned index entries. The bool is whether a
/// reference to it is exact -- a defined function, or an exact import.
pub type FunctionEntry = (@type_store.Id, String, Bool)?

///|
/// A global's entry: whether it is mutable, and its type.
///
/// The type is `None` for a global whose initializer failed to type -- a poison
/// global, read as an error to avoid cascades, exactly as for a local.
pub type GlobalEntry = (Bool, @infer.InferredValType?)

///|
/// A local's entry: its type, and where it was bound.
///
/// The span is for go-to-definition. The type is `None` when the initializer
/// failed to type -- an error-recovery poison local.
pub type LocalEntry = (@infer.InferredValType?, @basic.Location)

///|
/// One enclosing control frame: the label it can be branched to by, and the
/// types it delivers.
///
/// The label is kept as its `Ident` rather than a string so a branch can be
/// linked back to the labelled construct for go-to-definition.
pub struct ControlFrame {
  label : @ast.Ident?
  results : Array[@infer.Cell[@infer.InferredType]]
}

///|
/// Everything in scope while checking one configuration of one module.
///
/// It is a large record because a wasm module has a lot of index spaces, and
/// most of the fields are one of them. What is worth reading carefully is which
/// fields are per-FUNCTION -- those are reset on entry to each -- and which are
/// shared refs, because a shared ref is how a fact discovered deep inside a
/// block reaches the function level.
pub struct ModuleContext {
  // --- Whole-run configuration ---
  diagnostics : @diagnostic.Context
  /// Report a `let`-bound local that is never read. Only when validation was
  /// asked for.
  warn_unused : Bool
  /// Rewrite the AST while checking: drop casts the inferred types make
  /// redundant, tighten `&?extern`/`&?any` casts. Only when converting FROM
  /// wasm; hand-written Wax keeps its casts as written.
  simplify : Bool
  /// Emit the same rewrites as suggestions carrying machine-applicable edits,
  /// without touching the AST. Mutually exclusive with `simplify`.
  suggest : Bool
  /// The `--faithful` decompilation mode: casts are kept as under a plain
  /// re-type, except the scaffolding cast on a `call_ref` callee, which is
  /// still dropped when redundant so it does not re-lower to a spurious
  /// `ref.cast`.
  faithful : Bool

  // --- Module-wide tables, built once before any body ---
  type_context : TypeContext
  types : Tbl[(@type_store.RefIndex, @ast.SubType)]
  functions : Tbl[FunctionEntry]
  globals : Tbl[GlobalEntry]
  /// The globals a TABLE initializer can see: only the imported ones. A table
  /// is checked before the module's own globals are registered, unlike a global
  /// initializer, which sees the globals declared before it.
  import_globals : Tbl[GlobalEntry]
  tags : Tbl[@ast.FuncType]
  memories : Tbl[(Int, @wasm_types.AddressType)]
  datas : Tbl[Unit]
  tables : Tbl[(@wasm_types.AddressType, @wasm_types.RefType[@ast.Ident])]
  elems : Tbl[@wasm_types.RefType[@ast.Ident]]
  /// Names of the globals assigned anywhere in the module. A mutable global
  /// missing from this could have been declared `const`.
  ///
  /// Deliberately NOT filtered by reachability: rewriting a `let` that only a
  /// dead function assigns into a `const` would not type-check, so a textual
  /// assignment is enough to keep the `mut`.
  assigned_globals : Map[String, Unit]
  /// Spans of the casts already found to trap on every value, so a cast whose
  /// OPERAND always traps is not reported as well -- its verdict follows from
  /// the inner one, and the fix belongs there. Nested casts share a start
  /// position, so the two reports would also render as the same line.
  cast_traps_reported : Map[(Int, Int), Unit]
  /// Type references made by CANONICAL index rather than by name, for the uses
  /// that name no definition syntactically -- a string literal builds the
  /// canonical `mut i8` array, so every source definition that deduplicated
  /// onto it is used by that literal.
  canonical_type_references : Array[(Origin, @type_store.Id)]
  /// Where references are currently being made from. The same ref every table
  /// above holds.
  origin : Ref[Origin]
  /// A struct's canonical field-set key to the unique struct type with that
  /// field set, or `None` when several share it. Lets a struct literal whose
  /// name is omitted resolve from its fields alone.
  structs_by_fields : Map[String, @ast.Ident?]
  /// Spans already told "an expression is expected here". That query has a
  /// reporting side effect and one node is legitimately asked by several
  /// consumers -- a call's callee twice, a labelled block as both value and
  /// statement -- so it fires once per span.
  not_expression_reported : Map[(Int, Int), Unit]

  // --- Per-function state, reset on entry to each ---
  mut locals : Map[String, LocalEntry]
  /// Locals known to hold a value here. A non-defaultable local starts
  /// uninitialized and must be assigned before it is read. Captured on block
  /// entry, so an assignment inside a block does not escape it.
  mut initialized_locals : Map[String, Unit]
  /// A stack of collectors for uninitialized reads deferred by a trailing
  /// operand checked out of emission order. While non-empty, such a read
  /// funnels into the innermost collector instead of reporting, to be
  /// re-checked against the true state at the operand's real slot.
  mut deferred_uninit : Array[Array[@ast.Ident]]
  /// Whether a branch in this function failed to resolve its label. While set,
  /// a value-shape complaint is suppressed as a likely cascade: a block whose
  /// only value delivery was the unresolved branch legitimately computes no
  /// value, and saying so would anchor a derived error away from the unbound
  /// label.
  unresolved_label : Ref[Bool]
  /// Source offsets of the local DECLARATIONS read so far. Keyed by the
  /// binding's offset rather than its name, so a shadowing inner local does not
  /// mask the outer one as read.
  read_locals : Array[Int]
  /// The `let`-bound locals declared here, in order, so an unread one can be
  /// reported.
  local_decls : Array[@ast.Ident]
  /// Source offsets of the block-label DECLARATIONS branched to. Keyed by
  /// offset for the same shadowing reason as `read_locals`; the wasm validator
  /// likewise tracks usage per control frame.
  used_labels : Array[Int]
  /// Lints that must read a result cell only once checking has pinned it -- the
  /// shift-count lint reads the shifted operand's width, which a later context
  /// can widen. Flushed when every cell is final.
  deferred_lints : Array[() -> Unit]
  /// The block labels declared in this function's body, collected up front, so
  /// one never branched to can be reported.
  mut label_decls : Array[@ast.Ident]
  /// Names of locals assigned anywhere in this function, collected on entry.
  /// Lets the annotation-drop on a fused `let x: T = e` tell a write-once local
  /// -- which may narrow to `e`'s subtype -- from one a later assignment still
  /// needs the wider `T` for.
  mut assigned_locals : Map[String, Unit]
  mut control_types : Array[ControlFrame]
  mut return_types : Array[@infer.Cell[@infer.InferredType]]

  // --- Conditional compilation ---
  /// The current branch assumption, shared with every table above.
  cond : Ref[@cond.T]
  cond_env : @cond.Env

  // --- Editor sinks, all absent outside the editor ---
  resolve_links : ResolveSink
  pun_spans : Array[@basic.Location]?
  member_completions : Array[(@basic.Location, @members.MemberReceiver)]?
}

///|
/// Clear the per-function state on entry to a function.
///
/// The fields this touches are exactly the ones whose comments say "reset per
/// function" -- gathering them here is what makes that claim checkable rather
/// than a set of promises spread through the record.
pub fn ModuleContext::enter_function(
  self : ModuleContext,
  return_types~ : Array[@infer.Cell[@infer.InferredType]],
  label_decls? : Array[@ast.Ident] = [],
  assigned_locals? : Map[String, Unit] = Map([]),
) -> Unit {
  self.locals = Map([])
  self.initialized_locals = Map([])
  self.deferred_uninit = []
  self.unresolved_label.val = false
  self.read_locals.clear()
  self.local_decls.clear()
  self.used_labels.clear()
  self.label_decls = label_decls
  self.assigned_locals = assigned_locals
  self.control_types = []
  self.return_types = return_types
}

///|
/// Run `f` inside a control frame, restoring the enclosing one afterwards.
///
/// The reference builds a fresh context with `{ ctx with control_types = ... }`,
/// which restores by construction. Save and restore is the same thing, and is
/// what keeps a frame from outliving the block that opened it.
pub fn[A] ModuleContext::with_frame(
  self : ModuleContext,
  frame : ControlFrame,
  f : () -> A,
) -> A {
  let saved = self.control_types
  let inner = [frame]
  for c in saved {
    inner.push(c)
  }
  self.control_types = inner
  let r = f()
  self.control_types = saved
  r
}

///|
/// Run `f` with a snapshot of which locals are initialized, restoring it
/// afterwards.
///
/// An assignment inside a block must not escape it: the block may not run. But
/// within a straight-line sequence the set only grows, which is what lets a
/// trailing operand checked out of emission order be reconciled later.
pub fn[A] ModuleContext::with_initialized_snapshot(
  self : ModuleContext,
  f : () -> A,
) -> A {
  let saved = Map([])
  for k, v in self.initialized_locals {
    saved[k] = v
  }
  let r = f()
  self.initialized_locals = saved
  r
}

///|
pub fn ControlFrame::new(
  results : Array[@infer.Cell[@infer.InferredType]],
  label? : @ast.Ident? = None,
) -> ControlFrame {
  { label, results }
}

///|
/// Build the context for checking one configuration of one module.
///
/// Every table is created here rather than by the caller, because they all have
/// to share the same `cond` and `origin` refs -- that sharing is what lets a
/// branch assumption set in one place be seen by a lookup in another, and what
/// lets a reference be attributed without the origin being threaded through
/// every call. A constructor is the only place that can guarantee it.
pub fn ModuleContext::new(
  diagnostics : @diagnostic.Context,
  store : @type_store.TypeStore,
  features : @feature.Set,
  warn_unused? : Bool = false,
  simplify? : Bool = false,
  suggest? : Bool = false,
  faithful? : Bool = false,
  resolve_links? : ResolveSink = None,
  pun_spans? : Array[@basic.Location]? = None,
  member_completions? : Array[(@basic.Location, @members.MemberReceiver)]? = None,
) -> ModuleContext {
  let cond = @ref.new(@cond.true_)
  let origin = @ref.new(Origin::Root)
  let ns = Namespace::new(cond, links=resolve_links)
  // A hover on a type name shows what it is defined as; one on a bare global
  // shows its type. Everything else is not a name a hover has anything to say
  // about, and takes the default.
  let types : Tbl[(@type_store.RefIndex, @ast.SubType)] = Tbl::new(
    "type",
    ns,
    origin,
    hover=r => Some(TypeDef(r.1)),
  )
  let globals : Tbl[GlobalEntry] = Tbl::new("global", ns, origin, hover=g => {
    g.1.map(v => HoverTarget::ValueType(v))
  })
  let import_globals : Tbl[GlobalEntry] = Tbl::new("global", ns, origin, hover=g => {
    g.1.map(v => HoverTarget::ValueType(v))
  })
  let functions : Tbl[FunctionEntry] = Tbl::new("function", ns, origin)
  let tags : Tbl[@ast.FuncType] = Tbl::new("tag", ns, origin)
  let memories : Tbl[(Int, @wasm_types.AddressType)] = Tbl::new(
    "memory", ns, origin,
  )
  let datas : Tbl[Unit] = Tbl::new("data segment", ns, origin)
  let tables : Tbl[(@wasm_types.AddressType, @wasm_types.RefType[@ast.Ident])] = Tbl::new(
    "table", ns, origin,
  )
  let elems : Tbl[@wasm_types.RefType[@ast.Ident]] = Tbl::new(
    "element segment", ns, origin,
  )
  {
    diagnostics,
    warn_unused,
    simplify,
    suggest,
    faithful,
    type_context: TypeContext::new(store, types, features),
    types,
    functions,
    globals,
    import_globals,
    tags,
    memories,
    datas,
    tables,
    elems,
    assigned_globals: Map([]),
    cast_traps_reported: Map([]),
    canonical_type_references: [],
    origin,
    structs_by_fields: Map([]),
    not_expression_reported: Map([]),
    locals: Map([]),
    initialized_locals: Map([]),
    deferred_uninit: [],
    unresolved_label: @ref.new(false),
    read_locals: [],
    local_decls: [],
    used_labels: [],
    deferred_lints: [],
    label_decls: [],
    assigned_locals: Map([]),
    control_types: [],
    return_types: [],
    cond,
    cond_env: @cond.Env::new(),
    resolve_links,
    pun_spans,
    member_completions,
  }
}

///|
/// A copy of which locals currently hold a value.
pub fn ModuleContext::snapshot_initialized(
  self : ModuleContext,
) -> Map[String, Unit] {
  let out : Map[String, Unit] = Map([])
  for k, v in self.initialized_locals {
    out[k] = v
  }
  out
}

///|
/// Put back a snapshot, discarding whatever has been initialized since.
pub fn ModuleContext::restore_initialized(
  self : ModuleContext,
  saved : Map[String, Unit],
) -> Unit {
  self.initialized_locals = saved
}

///|
/// Add to the set, without disturbing what is already in it.
pub fn ModuleContext::merge_initialized(
  self : ModuleContext,
  extra : Map[String, Unit],
) -> Unit {
  for k, v in extra {
    self.initialized_locals[k] = v
  }
}

///|
/// Open a collector for uninitialized reads that are to be deferred rather than
/// reported, and return it.
pub fn ModuleContext::push_deferral(self : ModuleContext) -> Array[@ast.Ident] {
  let collector : Array[@ast.Ident] = []
  self.deferred_uninit.push(collector)
  collector
}

///|
/// Close the innermost collector.
pub fn ModuleContext::pop_deferral(self : ModuleContext) -> Unit {
  let _ = self.deferred_uninit.pop()
}

///|
/// The innermost open collector, if any.
pub fn ModuleContext::current_deferral(
  self : ModuleContext,
) -> Array[@ast.Ident]? {
  if self.deferred_uninit.is_empty() {
    None
  } else {
    Some(self.deferred_uninit[self.deferred_uninit.length() - 1])
  }
}
