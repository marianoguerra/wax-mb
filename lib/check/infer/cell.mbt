// Mutable inference cells: union-find over a value.
//
// Ported from the `Cell` module of wax/src/lib-wax/infer.ml. Unifying two
// values during inference means making them the same cell -- so that narrowing
// one narrows the other -- and that is exactly a union-find with the type as
// the root's payload.

///|
/// A cell's link to its class, or the class's value at the root.
///
/// `pub(all)` only because MoonBit will not let a public struct hold a private
/// type; nothing outside builds one.
enum State[A] {
  Link(Cell[A])
  Root(A)
}

///|
/// A value that inference may narrow, shared with everything unified with it.
///
/// The field is deliberately not part of the interface: `make`, `get`, `merge`
/// and `set` are, and the union-find underneath is nobody else's business.
pub struct Cell[A] {
  mut state : State[A]
}

///|
/// A fresh cell of its own class.
pub fn[A] Cell::make(value : A) -> Cell[A] {
  { state: Root(value) }
}

///|
/// The root of this cell's class, compressing the path to it on the way: every
/// link followed is repointed straight at the root.
fn[A] Cell::representative(self : Cell[A]) -> Cell[A] {
  match self.state {
    Root(_) => self
    Link(next) => {
      let root = next.representative()
      if !physical_equal(next, root) {
        self.state = Link(root)
      }
      root
    }
  }
}

///|
/// The value of this cell's class.
pub fn[A] Cell::get(self : Cell[A]) -> A {
  match self.representative().state {
    Root(v) => v
    // `representative` returns a root by construction.
    Link(_) => abort("Cell::get: representative is not a root")
  }
}

///|
/// Unify two cells and give the shared class `value`.
pub fn[A] Cell::merge(self : Cell[A], other : Cell[A], value : A) -> Unit {
  let a = self.representative()
  let b = other.representative()
  if physical_equal(a, b) {
    a.state = Root(value)
  } else {
    a.state = Link(b)
    b.state = Root(value)
  }
}

///|
/// Overwrite the value at this cell's root.
pub fn[A] Cell::set(self : Cell[A], value : A) -> Unit {
  self.representative().state = Root(value)
}

///|
/// Are these the same cell, rather than two cells that merely hold equal
/// values?
///
/// Identity matters wherever a cell is used as a TOKEN rather than as a type:
/// the underflow placeholders are looked up this way, because two missing
/// values both recorded as `Error` are still two different missing values.
pub fn[A] same_cell(a : Cell[A], b : Cell[A]) -> Bool {
  physical_equal(a, b)
}
