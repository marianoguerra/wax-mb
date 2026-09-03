// The index spaces a wasm module is written in terms of.
//
// Ported from `reorder_imports` in wax/src/lib-conversion/to_wasm.ml together
// with the name resolution of wax/src/lib-wasm/text_to_binary.ml -- the two are
// one job here, because this lowering goes straight to the indexed form rather
// than through a text AST that still carries names.
//
// The ordering rule is the format's, not ours: within each space the IMPORTS
// come first, in the order they were written, and the module's own definitions
// follow. A wax module may interleave them freely, so the first pass is entirely
// about putting them back in the order the binary requires.

///|
/// A name-to-index map for one index space.
///
/// A name may be declared MORE THAN ONCE -- under two mutually exclusive
/// conditions, where only one of them is ever really there. Each declaration
/// takes its own slot, because that is what the module holds when both
/// branches are lowered side by side for the text form, and each records where
/// it was written so a reference can be answered from the site that asks.
struct Space {
  by_name : Map[String, Array[(Int, @basic.Location)]]
  mut next : Int
}

///|
pub fn Space::new() -> Space {
  { by_name: Map([]), next: 0, }
}

///|
/// Assign the next index to `name`, and return it.
fn Space::assign(self : Space, name : String, loc : @basic.Location) -> Int {
  let i = self.next
  self.next = i + 1
  match self.by_name.get(name) {
    Some(l) => l.push((i, loc))
    None => self.by_name[name] = [(i, loc)]
  }
  i
}

///|
/// The index a name was given, or `None` if it never was.
///
/// The FIRST declaration, for a caller with no site to resolve against.
pub fn Space::get(self : Space, name : String) -> Int? {
  match self.by_name.get(name) {
    Some(l) => Some(l[0].0)
    None => None
  }
}

///|
/// The declaration of `name` that a reference at `at` can see.
///
/// Conditional branches make one name several declarations, and which one a
/// reference means is decided by where the reference stands: a declaration is
/// visible from a site inside it, so the one whose guards are the longest
/// prefix of the site's is the one meant. A declaration under no condition is
/// visible everywhere, which is the prefix of length zero.
pub fn Space::resolve(
  self : Space,
  name : String,
  at : Array[(Int, Bool)],
  guards : (@basic.Location) -> Array[(Int, Bool)],
) -> Int? {
  guard self.by_name.get(name) is Some(l) else { return None }
  if l.length() == 1 {
    return Some(l[0].0)
  }
  let mut best : Int? = None
  let mut best_len = -1
  for entry in l {
    let g = guards(entry.1)
    guard g.length() <= at.length() else { continue }
    let mut ok = true
    for k in 0..<g.length() {
      if g[k] != at[k] {
        ok = false
        break
      }
    }
    if ok && g.length() > best_len {
      best_len = g.length()
      best = Some(entry.0)
    }
  }
  match best {
    Some(_) => best
    None => Some(l[0].0)
  }
}

///|
/// How many entries this space holds.
pub fn Space::length(self : Space) -> Int {
  self.next
}

///|
/// Every index space of one module.
struct Indices {
  funcs : Space
  globals : Space
  memories : Space
  tables : Space
  tags : Space
  datas : Space
  elems : Space
}

///|
pub fn Indices::new() -> Indices {
  {
    funcs: Space::new(),
    globals: Space::new(),
    memories: Space::new(),
    tables: Space::new(),
    tags: Space::new(),
    datas: Space::new(),
    elems: Space::new(),
  }
}

///|
/// Walk the module twice, assigning every index.
///
/// Twice because the format puts imports first in every space they touch, and a
/// wax module may write them anywhere -- so the first walk claims the imported
/// indices and the second claims the rest. Doing it in one pass would give a
/// definition written above an import the lower index, which is the one thing
/// the binary format does not allow.
fn assign_indices(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Indices {
  let idx = Indices::new()
  fn claim_import(decl : @ast.ImportDecl) -> Unit {
    match decl.kind {
      Func(..) => {
        let _ = idx.funcs.assign(decl.id.name, decl.id.loc)
      }
      Global(..) => {
        let _ = idx.globals.assign(decl.id.name, decl.id.loc)
      }
      Memory(..) => {
        let _ = idx.memories.assign(decl.id.name, decl.id.loc)
      }
      Table(..) => {
        let _ = idx.tables.assign(decl.id.name, decl.id.loc)
      }
      Tag(..) => {
        let _ = idx.tags.assign(decl.id.name, decl.id.loc)
      }
    }
  }

  @typing.walk_fields(ctx, fields, field => {
    match field.desc {
      Import(decl~, ..) => claim_import(decl.desc)
      ImportGroup(decls~, ..) =>
        for d in decls {
          claim_import(d.desc)
        }
      _ => ()
    }
  })
  @typing.walk_fields(ctx, fields, field => {
    match field.desc {
      Func(name~, ..) => {
        let _ = idx.funcs.assign(name.name, name.loc)
      }
      Global(name~, ..) => {
        let _ = idx.globals.assign(name.name, name.loc)
      }
      Memory(name~, data~, ..) => {
        let _ = idx.memories.assign(name.name, name.loc)
        // An inline data segment lives in the data space like any other, and is
        // numbered where it is written.
        for d in data {
          if d.data_name is Some(n) {
            let _ = idx.datas.assign(n.name, n.loc)
          }
        }
      }
      Table(name~, ..) => {
        let _ = idx.tables.assign(name.name, name.loc)
      }
      Tag(name~, ..) => {
        let _ = idx.tags.assign(name.name, name.loc)
      }
      Data(name~, ..) =>
        if name is Some(n) {
          let _ = idx.datas.assign(n.name, n.loc)
        }
      Elem(name~, ..) => {
        let _ = idx.elems.assign(name.name, name.loc)
      }
      _ => ()
    }
  })
  idx
}
