// The least upper bound of two reference types.
//
// Ported from wax/src/lib-wax/typing.ml.
//
// This is the piece `join_value_types` has been taking as a parameter since the
// block-exit fold: everything else about a join is decided by the
// flexible-literal lattice, and only THIS needs the type table, because walking
// two concrete types to a common supertype means following their declared
// supertype chains.
//
// The abstract cases below are not a lookup table anyone chose -- they are the
// wasm type hierarchy written out. Four hierarchies (`any`, `func`, `extern`,
// `exn`) plus continuations, each with its own bottom, and no value is in two
// of them, so a pair drawn from different hierarchies has no upper bound at
// all.

///|
/// The supertype a defined type sits directly under.
///
/// A declared supertype if there is one; otherwise the abstract type its shape
/// puts it beneath.
fn immediate_supertype(s : @ast.SubType) -> @wasm_types.HeapType[@ast.Ident] {
  match (s.supertype, s.typ) {
    (Some(t), _) => Type(t)
    (None, Struct(_)) => Struct
    (None, Array(_)) => Array
    (None, Func(_)) => Func
    (None, Cont(_)) => Cont
  }
}

///|
/// The least upper bound of two heap types, or `None` when they have none.
///
/// Concrete types are walked up their supertype chains until they meet, taking
/// whichever is currently DEEPER -- compared by store index, since a supertype
/// is always interned before its subtypes. That termination argument is the
/// whole reason `add_type` drops a supertype the spec forbids: a cyclic chain
/// here would not terminate.
pub fn heap_lub(
  ctx : @typing_env.TypeContext,
  h1 : @wasm_types.HeapType[@ast.Ident],
  h2 : @wasm_types.HeapType[@ast.Ident],
) -> @wasm_types.HeapType[@ast.Ident]? {
  // A bottom reference is below everything in its own hierarchy, so its lub
  // with anything from that hierarchy is that other type. Handled before the
  // concrete walk, which would otherwise climb past a `$t` to `struct` and
  // over-generalise `lub(none, $t)`.
  if is_bottom_heaptype(h1) && same_hierarchy(ctx, h1, h2) {
    return Some(h2)
  }
  if is_bottom_heaptype(h2) && same_hierarchy(ctx, h1, h2) {
    return Some(h1)
  }
  match (h1, h2) {
    // `exact` survives only when both sides are the same exact type; any
    // generalization at all drops exactness, since the result then admits
    // subtypes the exact form excludes.
    (Exact(a), Exact(b)) => {
      let ia = resolve_index(ctx, a)
      let ib = resolve_index(ctx, b)
      if ia is Some(x) && ib is Some(y) && x == y {
        Some(Exact(a))
      } else {
        heap_lub(ctx, Type(a), Type(b))
      }
    }
    (Exact(a), _) => heap_lub(ctx, Type(a), h2)
    (_, Exact(b)) => heap_lub(ctx, h1, Type(b))
    (Type(a), Type(b)) => {
      guard type_depth(ctx, a) is Some(ia) else { return None }
      guard type_depth(ctx, b) is Some(ib) else { return None }
      if ia == ib {
        return Some(h1)
      }
      // Climb the deeper one, so the two converge rather than one running away.
      if ia > ib {
        guard ctx.types.find_no_mark(a.name) is Some((_, sa)) else {
          return None
        }
        heap_lub(ctx, immediate_supertype(sa), h2)
      } else {
        guard ctx.types.find_no_mark(b.name) is Some((_, sb)) else {
          return None
        }
        heap_lub(ctx, h1, immediate_supertype(sb))
      }
    }
    (Type(a), _) => {
      guard ctx.types.find_no_mark(a.name) is Some((_, sa)) else { return None }
      heap_lub(ctx, immediate_supertype(sa), h2)
    }
    (_, Type(b)) => {
      guard ctx.types.find_no_mark(b.name) is Some((_, sb)) else { return None }
      heap_lub(ctx, h1, immediate_supertype(sb))
    }
    // --- The abstract hierarchies, written out ---
    (None_, None_) => Some(None_)
    (None_ | I31, I31) | (I31, None_) => Some(I31)
    (None_ | Struct, Struct) | (Struct, None_) => Some(Struct)
    (None_ | Array, Array) | (Array, None_) => Some(Array)
    (None_ | I31 | Struct | Array | Eq, Eq)
    | (Eq, None_ | I31 | Struct | Array)
    | (Struct | Array, I31)
    | (I31, Struct | Array)
    | (Struct, Array)
    | (Array, Struct) => Some(Eq)
    (None_ | I31 | Struct | Array | Eq | Any, Any)
    | (Any, None_ | Eq | I31 | Struct | Array) => Some(Any)
    (NoFunc, NoFunc) => Some(NoFunc)
    (NoFunc | Func, Func) | (Func, NoFunc) => Some(Func)
    (NoExtern, NoExtern) => Some(NoExtern)
    (NoExtern | Extern, Extern) | (Extern, NoExtern) => Some(Extern)
    (NoExn, NoExn) => Some(NoExn)
    (NoExn | Exn, Exn) | (Exn, NoExn) => Some(Exn)
    (NoCont, NoCont) => Some(NoCont)
    (NoCont | Cont, Cont) | (Cont, NoCont) => Some(Cont)
    // Anything left pairs two different hierarchies, and no value is in two of
    // them.
    _ => None
  }
}

///|
/// The top of the hierarchy a heap type belongs to, for the bottom-reference
/// shortcut.
fn hierarchy_top(
  ctx : @typing_env.TypeContext,
  h : @wasm_types.HeapType[@ast.Ident],
) -> @wasm_types.HeapType[@ast.Ident]? {
  match h {
    None_ | Eq | I31 | Struct | Array | Any => Some(Any)
    NoFunc | Func => Some(Func)
    NoExtern | Extern => Some(Extern)
    NoExn | Exn => Some(Exn)
    NoCont | Cont => Some(Cont)
    Type(n) | Exact(n) =>
      match ctx.types.find_no_mark(n.name) {
        Some((_, s)) =>
          match s.typ {
            Struct(_) | Array(_) => Some(Any)
            Func(_) => Some(Func)
            Cont(_) => Some(Cont)
          }
        None => None
      }
  }
}

///|
fn same_hierarchy(
  ctx : @typing_env.TypeContext,
  a : @wasm_types.HeapType[@ast.Ident],
  b : @wasm_types.HeapType[@ast.Ident],
) -> Bool {
  match (hierarchy_top(ctx, a), hierarchy_top(ctx, b)) {
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
/// A type name's index, without marking it referenced.
fn resolve_index(
  ctx : @typing_env.TypeContext,
  n : @ast.Ident,
) -> @type_store.RefIndex? {
  ctx.types.find_no_mark(n.name).map(r => r.0)
}

///|
/// How deep a defined type sits, as its position in the store.
///
/// A supertype is always interned before its subtypes, so a larger index means
/// deeper -- which is what lets the walk climb the deeper side and converge
/// rather than have one run away from the other.
fn type_depth(ctx : @typing_env.TypeContext, n : @ast.Ident) -> Int? {
  match resolve_index(ctx, n) {
    Some(Def(id)) => Some(id.to_int_for_tests_only())
    Some(Rec(pos)) => Some(pos)
    None => None
  }
}

///|
/// The least upper bound of two value types.
///
/// Only references have one to compute: any other pair either is the same type
/// or has nothing in common, because the numeric types form no hierarchy.
///
/// Nullability is the OR of the two, since a value that may be null on either
/// side may be null in the result.
pub fn val_lub(
  ctx : @typing_env.TypeContext,
  v1 : @wasm_types.ValType[@ast.Ident],
  v2 : @wasm_types.ValType[@ast.Ident],
) -> @wasm_types.ValType[@ast.Ident]? {
  match (v1, v2) {
    (Ref(r1), Ref(r2)) =>
      heap_lub(ctx, r1.typ, r2.typ).map(lub => {
        @wasm_types.ValType::Ref({
          nullable: r1.nullable || r2.nullable,
          typ: lub,
        })
      })
    _ => if v1 == v2 { Some(v1) } else { None }
  }
}

///|
/// The lub as the join wants it: over inferred value types, resolving the
/// result back into the store.
///
/// This is the function `join_value_types` takes as a parameter, and the reason
/// it takes one: the fold itself needs no type table, and only this does.
fn inferred_lub(
  ctx : @typing_env.TypeContext,
  diagnostics : @diagnostic.Context,
) -> ValLub {
  (a, b) => {
    match val_lub(ctx, a.typ, b.typ) {
      Some(v) => internalize_valtype(ctx, diagnostics, v)
      None => None
    }
  }
}
