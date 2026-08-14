// The store itself: registering rec groups, deduplicating them, and answering
// subtyping questions about what is in it.

///|
/// A rec group that is not well-formed.
///
/// The reference raises `Invalid_argument` here. It is a backstop rather than a
/// user-facing diagnostic: a violation means the caller mis-normalized the
/// group, which is the source-versus-canonical index confusion class, and is
/// rejected rather than left to silently corrupt the subtyping relation.
suberror MalformedRecGroup {
  /// A `Rec` back-reference that does not name a member of this group.
  BackReferenceOutOfGroup(Int, Int)
  /// A `Def` naming a type that is not defined yet -- including one in this
  /// very group, which has to be spelled `Rec`.
  UndefinedReference(Int)
} derive(Eq, Debug)

///|
pub impl Show for MalformedRecGroup with fn output(self, logger) {
  logger.write_string(
    match self {
      BackReferenceOutOfGroup(pos, len) =>
        "back-reference \{pos} is outside a rec group of \{len}"
      UndefinedReference(idx) =>
        "reference to type \{idx}, which is not defined yet"
    },
  )
}

///|
/// A context holding recursive type definitions.
pub struct TypeStore {
  /// Structurally equal rec groups share an entry, which is what makes a
  /// canonical index canonical.
  interned : Map[RecType[RefIndex], Int]
  /// The index the next freshly added type would receive.
  mut last_index : Int
  /// Every group registered, in order, each with the index its first member
  /// received.
  ///
  /// The reference calls this `rev_list` and reverses it on the way out,
  /// because OCaml prepends to a list. Appending to an array is already in
  /// order, so the name and the reversal both go -- keeping either would be
  /// carrying over the shape of the other language's data structure, and
  /// keeping the reversal silently mis-resolves every intra-group reference.
  groups : Array[(Int, RecType[RefIndex])]
}

///|
pub fn TypeStore::new() -> TypeStore {
  { interned: {}, last_index: 0, groups: [] }
}

///|
/// The index the next freshly added type would receive, i.e. how many types are
/// currently defined.
pub fn TypeStore::last_index(self : TypeStore) -> Int {
  self.last_index
}

///|
/// Check the normalization contract: a `Rec` must fall inside this group, and a
/// `Def` must name a type already defined. `last_index` is the base this group
/// is about to receive, so a well-formed `Def` is strictly below it.
fn TypeStore::check_normalized(
  self : TypeStore,
  group : RecType[RefIndex],
) -> Unit raise MalformedRecGroup {
  let n = group.length()
  let seen : Ref[MalformedRecGroup?] = @ref.new(None)
  for st in group {
    // `map` visits every reference; the result is discarded, only the check
    // matters. The reference does the same thing, mapping to a dummy index.
    let _ = st.map(r => {
      match r {
        Rec(pos) =>
          if (pos < 0 || pos >= n) && seen.val is None {
            seen.val = Some(BackReferenceOutOfGroup(pos, n))
          }
        Def(id) =>
          if (id.index < 0 || id.index >= self.last_index) && seen.val is None {
            seen.val = Some(UndefinedReference(id.index))
          }
      }
      0
    })
  }
  if seen.val is Some(e) {
    raise e
  }
}

///|
/// Register a rec group, returning the canonical index of its first member.
///
/// A structurally equal group already in the store is not added again: its
/// existing index is returned, which is what makes two spellings of the same
/// recursive type the same type.
pub fn TypeStore::add_rectype(
  self : TypeStore,
  group : RecType[RefIndex],
) -> Id raise MalformedRecGroup {
  self.check_normalized(group)
  if self.interned.get(group) is Some(index) {
    return { index, }
  }
  let index = self.last_index
  self.interned[group] = index
  self.last_index = index + group.length()
  self.groups.push((index, group))
  { index, }
}

///|
/// Resolve a reference to an absolute canonical index: a `Def` already is one,
/// a `Rec` is the group's `pos`-th member counting from `base`.
fn resolve_ref(base : Int, r : RefIndex) -> Id {
  match r {
    Def(id) => id
    Rec(pos) => { index: base + pos }
  }
}

///|
/// Everything needed to answer subtyping questions: every defined type, in
/// canonical index order, fully resolved.
pub struct SubtypingInfo {
  subtypes : Array[SubType[Id]]
}

///|
/// Resolve the whole store.
///
/// The reference memoises this on the context and invalidates it whenever a
/// type is added, because a query must see the current type space. The cache
/// belongs to the checker's `type_context` rather than here; this stays a pure
/// function of the store.
pub fn TypeStore::subtyping_info(self : TypeStore) -> SubtypingInfo {
  let out : Array[SubType[Id]] = []
  for entry in self.groups {
    let (base, group) = entry
    for st in group {
      out.push(st.map(r => resolve_ref(base, r)))
    }
  }
  { subtypes: out }
}

///|
pub fn SubtypingInfo::get_subtype(self : SubtypingInfo, id : Id) -> SubType[Id] {
  self.subtypes[id.index]
}

///|
/// Every rec group in the store, resolved, in the order they were registered.
pub fn TypeStore::get_all_rectypes(self : TypeStore) -> Array[RecType[Id]] {
  let out : Array[RecType[Id]] = []
  for entry in self.groups {
    let (base, group) = entry
    out.push(group.map(st => st.map(r => resolve_ref(base, r))))
  }
  out
}

// ============================================================
// Subtyping
// ============================================================

///|
/// Is `i` a subtype of `i'`, by walking declared supertypes?
fn sub_index(info : SubtypingInfo, i : Id, target : Id) -> Bool {
  for cur = i {
    if cur == target {
      break true
    }
    match info.get_subtype(cur).supertype {
      None => break false
      Some(s) => continue s
    }
  }
}

///|
/// Which top hierarchy a concrete type belongs to.
///
/// Each of these enumerates the `CompType` constructors rather than using a
/// wildcard, exactly as the reference does, so that adding a comptype forces
/// every one of them to be revisited.
fn is_struct(info : SubtypingInfo, i : Id) -> Bool {
  match info.get_subtype(i).typ {
    Struct(_) => true
    Func(_) | Array(_) | Cont(_) => false
  }
}

///|
fn is_array(info : SubtypingInfo, i : Id) -> Bool {
  match info.get_subtype(i).typ {
    Array(_) => true
    Func(_) | Struct(_) | Cont(_) => false
  }
}

///|
fn is_func(info : SubtypingInfo, i : Id) -> Bool {
  match info.get_subtype(i).typ {
    Func(_) => true
    Struct(_) | Array(_) | Cont(_) => false
  }
}

///|
fn is_cont(info : SubtypingInfo, i : Id) -> Bool {
  match info.get_subtype(i).typ {
    Cont(_) => true
    Func(_) | Struct(_) | Array(_) => false
  }
}

///|
fn is_aggregate(info : SubtypingInfo, i : Id) -> Bool {
  is_struct(info, i) || is_array(info, i)
}

///|
/// Is `ty` a subtype of `ty'`?
///
/// Matched supertype first, then subtype. The reference writes both arms
/// exhaustively and without a wildcard row so that a new heap type forces every
/// relevant arm to be revisited; the same discipline is kept here, which is why
/// this is long rather than clever.
///
/// An `Exact i` reference has the same proper supertypes as `i` (since
/// `exact i <: i`), so on the left it follows the `Type i` rules -- but among
/// concrete types `exact` is invariant, so on the right only the same exact
/// type matches. The bottom heap types are subtypes of the exact types too.
pub fn heap_subtype(
  info : SubtypingInfo,
  ty : @wasm_types.HeapType[Id],
  ty_ : @wasm_types.HeapType[Id],
) -> Bool {
  match ty_ {
    Func =>
      match ty {
        Func | NoFunc => true
        Type(i) | Exact(i) => is_func(info, i)
        Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_ => false
      }
    NoFunc =>
      match ty {
        NoFunc => true
        Func
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    Exn =>
      match ty {
        Exn | NoExn => true
        Func
        | NoFunc
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    NoExn =>
      match ty {
        NoExn => true
        Func
        | NoFunc
        | Exn
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    Cont =>
      match ty {
        Cont | NoCont => true
        Type(i) | Exact(i) => is_cont(info, i)
        Func
        | NoFunc
        | Exn
        | NoExn
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_ => false
      }
    NoCont =>
      match ty {
        NoCont => true
        Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    Extern =>
      match ty {
        Extern | NoExtern => true
        Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    NoExtern =>
      match ty {
        NoExtern => true
        Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | Any
        | Eq
        | I31
        | Struct
        | Array
        | None_
        | Type(_)
        | Exact(_) => false
      }
    Any =>
      match ty {
        Any | Eq | I31 | Struct | Array | None_ => true
        Type(i) | Exact(i) => is_aggregate(info, i)
        Func | NoFunc | Exn | NoExn | Cont | NoCont | Extern | NoExtern => false
      }
    Eq =>
      match ty {
        Eq | I31 | Struct | Array | None_ => true
        Type(i) | Exact(i) => is_aggregate(info, i)
        Any | Func | NoFunc | Exn | NoExn | Cont | NoCont | Extern | NoExtern =>
          false
      }
    I31 =>
      match ty {
        I31 | None_ => true
        Any
        | Eq
        | Struct
        | Array
        | Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Type(_)
        | Exact(_) => false
      }
    Struct =>
      match ty {
        Struct | None_ => true
        Type(i) | Exact(i) => is_struct(info, i)
        Any
        | Eq
        | I31
        | Array
        | Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern => false
      }
    Array =>
      match ty {
        Array | None_ => true
        Type(i) | Exact(i) => is_array(info, i)
        Any
        | Eq
        | I31
        | Struct
        | Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern => false
      }
    None_ =>
      match ty {
        None_ => true
        Any
        | Eq
        | I31
        | Struct
        | Array
        | Func
        | NoFunc
        | Exn
        | NoExn
        | Cont
        | NoCont
        | Extern
        | NoExtern
        | Type(_)
        | Exact(_) => false
      }
    Type(target) =>
      match ty {
        Type(i) | Exact(i) => sub_index(info, i, target)
        None_ => is_aggregate(info, target)
        NoFunc => is_func(info, target)
        NoCont => is_cont(info, target)
        Func
        | Exn
        | NoExn
        | Cont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array => false
      }
    Exact(target) =>
      match ty {
        // `exact` is invariant among concrete types: only the same one.
        Exact(i) => i == target
        None_ => is_aggregate(info, target)
        NoFunc => is_func(info, target)
        NoCont => is_cont(info, target)
        Type(_)
        | Func
        | Exn
        | NoExn
        | Cont
        | Extern
        | NoExtern
        | Any
        | Eq
        | I31
        | Struct
        | Array => false
      }
  }
}

///|
/// A non-nullable reference is a subtype of a nullable one, never the reverse.
pub fn ref_subtype(
  info : SubtypingInfo,
  rt : @wasm_types.RefType[Id],
  rt_ : @wasm_types.RefType[Id],
) -> Bool {
  (!rt.nullable || rt_.nullable) && heap_subtype(info, rt.typ, rt_.typ)
}

///|
/// Subtyping is only interesting between references; every other value type is
/// a subtype of itself alone.
pub fn val_subtype(
  info : SubtypingInfo,
  ty : @wasm_types.ValType[Id],
  ty_ : @wasm_types.ValType[Id],
) -> Bool {
  match (ty, ty_) {
    (Ref(t), Ref(t_)) => ref_subtype(info, t, t_)
    _ => ty == ty_
  }
}
