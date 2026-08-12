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
pub struct Space {
  by_name : Map[String, Int]
  mut next : Int
}

///|
pub fn Space::new() -> Space {
  { by_name: Map([]), next: 0 }
}

///|
/// Assign the next index to `name`, and return it.
///
/// A name already present keeps its first index: a wax module can declare the
/// same name under two mutually exclusive conditions, and only one of them is
/// ever really there.
pub fn Space::assign(self : Space, name : String) -> Int {
  match self.by_name.get(name) {
    Some(i) => i
    None => {
      let i = self.next
      self.by_name[name] = i
      self.next = i + 1
      i
    }
  }
}

///|
/// The index a name was given, or `None` if it never was.
pub fn Space::get(self : Space, name : String) -> Int? {
  self.by_name.get(name)
}

///|
/// How many entries this space holds.
pub fn Space::length(self : Space) -> Int {
  self.next
}

///|
/// Every index space of one module.
pub struct Indices {
  funcs : Space
  globals : Space
  memories : Space
  tables : Space
  tags : Space
  datas : Space
  elems : Space
  /// How many of each space are IMPORTS, which the format requires to come
  /// first. Kept because a definition's index is its position AFTER them.
  mut imported_funcs : Int
  mut imported_globals : Int
  mut imported_memories : Int
  mut imported_tables : Int
  mut imported_tags : Int
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
    imported_funcs: 0,
    imported_globals: 0,
    imported_memories: 0,
    imported_tables: 0,
    imported_tags: 0,
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
pub fn assign_indices(
  ctx : @typing_env.ModuleContext,
  fields : @ast.Module[@basic.Location],
) -> Indices {
  let idx = Indices::new()
  fn claim_import(decl : @ast.ImportDecl) -> Unit {
    match decl.kind {
      Func(..) => {
        let _ = idx.funcs.assign(decl.id.name)
      }
      Global(..) => {
        let _ = idx.globals.assign(decl.id.name)
      }
      Memory(..) => {
        let _ = idx.memories.assign(decl.id.name)
      }
      Table(..) => {
        let _ = idx.tables.assign(decl.id.name)
      }
      Tag(..) => {
        let _ = idx.tags.assign(decl.id.name)
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
  idx.imported_funcs = idx.funcs.length()
  idx.imported_globals = idx.globals.length()
  idx.imported_memories = idx.memories.length()
  idx.imported_tables = idx.tables.length()
  idx.imported_tags = idx.tags.length()
  @typing.walk_fields(ctx, fields, field => {
    match field.desc {
      Func(name~, ..) => {
        let _ = idx.funcs.assign(name.name)
      }
      Global(name~, ..) => {
        let _ = idx.globals.assign(name.name)
      }
      Memory(name~, data~, ..) => {
        let _ = idx.memories.assign(name.name)
        // An inline data segment lives in the data space like any other, and is
        // numbered where it is written.
        for d in data {
          if d.data_name is Some(n) {
            let _ = idx.datas.assign(n.name)
          }
        }
      }
      Table(name~, ..) => {
        let _ = idx.tables.assign(name.name)
      }
      Tag(name~, ..) => {
        let _ = idx.tags.assign(name.name)
      }
      Data(name~, ..) => if name is Some(n) { let _ = idx.datas.assign(n.name) }
      Elem(name~, ..) => {
        let _ = idx.elems.assign(name.name)
      }
      _ => ()
    }
  })
  idx
}
