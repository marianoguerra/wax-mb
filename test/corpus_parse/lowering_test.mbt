// The surface-form lowerings, on real parsed input.
//
// `lower_while` / `lower_match` / `lower_dispatch` rewrite a surface construct
// into the core forms a type checker and a code generator understand. Nothing
// consumes them yet, so what pins them is their SHAPE: each is the exact
// inverse of one of the reference's `recover_*` passes, so getting the nesting
// or the fall-through order wrong would surface much later, as a decompiled
// module that no longer re-lowers to the blocks it came from.
//
// The inputs are parsed rather than hand-built, so a change to how the parser
// shapes a `while` breaks this too -- which is why this lives here and not in
// the `ast` package.
//
// Shapes are compared as a compact sketch rather than as AST JSON: the JSON
// renderer spells out only the constructors the parse snapshots need and prints
// the rest as "...", which happens to include every branch instruction a
// lowering emits.

///|
/// The first `while` / `match` / `dispatch` anywhere in the source.
///
/// Found with `iter_instr`, which is itself part of what this file covers.
fn surface_stmt(src : String) -> @ast.Instr[@basic.Location] {
  let r = @grammar.parse_string(src)
  guard r.module_ is Some(fields) else { abort("did not parse: " + src) }
  let found : Array[@ast.Instr[@basic.Location]] = []
  for f in fields {
    match f.desc {
      Func(body~, ..) => {
        let (_, stmts) = body
        for stmt in stmts {
          stmt.iter_instr(i => {
            if i.desc is (While(..) | Match(..) | Dispatch(..)) &&
              found.length() == 0 {
              found.push(i)
            }
          })
        }
      }
      _ => ()
    }
  }
  if found.length() == 0 {
    abort("no surface construct in: " + src)
  }
  found[0]
}

///|
/// A one-line structural sketch: the control-flow skeleton, with labels.
fn sketch(i : @ast.Instr[@basic.Location]) -> String {
  fn lbl(l : @ast.Label?) -> String {
    match l {
      Some(x) => x.name
      None => "_"
    }
  }

  match i.desc {
    Block(label~, block~, ..) =>
      "block \{lbl(label)}[\{sketch_all(block.desc)}]"
    Loop(label~, block~, ..) => "loop \{lbl(label)}[\{sketch_all(block.desc)}]"
    If(cond~, if_block~, ..) =>
      "if \{sketch(cond)}[\{sketch_all(if_block.desc)}]"
    Br(l, None) => "br \{l.name}"
    Br(l, Some(v)) => "br \{l.name}(\{sketch(v)})"
    BrTable(targets, operand) => {
      let names = targets.map(t => t.name)
      "br_table[\{names.join(",")}](\{sketch(operand)})"
    }
    BrOnCast(l, _, operand) => "br_on_cast \{l.name}(\{sketch(operand)})"
    BrOnNull(l, operand) => "br_on_null \{l.name}(\{sketch(operand)})"
    Let(binds, Some(v)) => {
      let names = binds.map(b => {
        match b.0 {
          Some(n) => n.name
          None => "_"
        }
      })
      "let \{names.join(",")}=\{sketch(v)}"
    }
    Get(id) => id.name
    Set(id, _, v) => "\{id.name}=\{sketch(v)}"
    Nop => "nop"
    Int(s) => s
    BinOpI(_, l, r) => "(\{sketch(l)} op \{sketch(r)})"
    _ => "?"
  }
}

///|
fn sketch_all(xs : Array[@ast.Instr[@basic.Location]]) -> String {
  xs.map(sketch).join(" ")
}

///|
/// A fresh label, as the typer would mint one.
fn fresh(name : String) -> @ast.Ident {
  { name, loc: @basic.dummy_loc }
}

///|
test "while lowers to a loop around a leading test" {
  let stmt = surface_stmt("fn f() { while c { nop; } }")
  guard stmt.desc is While(label~, cond~, step~, block~)
  inspect(
    sketch_all(
      @ast.lower_while(
        stmt.info,
        fresh_loop=fresh(@ast.synthetic_loop_label),
        label~,
        cond~,
        step~,
        block=block.desc,
      ),
    ),
    content="loop #loop[if c[nop br #loop]]",
  )
}

///|
test "a labelled while keeps its own label on the loop" {
  // No step, so no wrapper block is needed and the user's label IS the
  // back-edge target: `continue` re-tests the condition directly.
  let stmt = surface_stmt("fn f() { 'l: while c { nop; } }")
  guard stmt.desc is While(label~, cond~, step~, block~)
  inspect(
    sketch_all(
      @ast.lower_while(
        stmt.info,
        fresh_loop=fresh(@ast.synthetic_loop_label),
        label~,
        cond~,
        step~,
        block=block.desc,
      ),
    ),
    content="loop l[if c[nop br l]]",
  )
}

///|
test "a stepped labelled while runs the step on the continue path" {
  // The body goes in a block carrying the USER's label, and the back-edge uses
  // a fresh one -- so `br 'l` exits the block, runs the step, and only then
  // loops. A `continue` that skipped the increment would spin forever.
  let stmt = surface_stmt(
    "fn f() { let i = 0; 'l: while i <u 4 : (i += 1) { nop; } }",
  )
  guard stmt.desc is While(label~, cond~, step~, block~)
  inspect(
    sketch_all(
      @ast.lower_while(
        stmt.info,
        fresh_loop=fresh(@ast.synthetic_loop_label),
        label~,
        cond~,
        step~,
        block=block.desc,
      ),
    ),
    content="loop #loop[if (i op 4)[block l[nop] i=1 br #loop]]",
  )
}

///|
test "dispatch lowers to a br_table in nested case blocks" {
  // Arms are in fall-through order, which is the REVERSE of the nesting: the
  // last arm is outermost and its body trails the whole structure, which is why
  // this returns a list.
  let stmt = surface_stmt(
    "fn f(x: i32) { dispatch x [ 'a, 'b, else 'd ] { 'a: { nop; } 'b: { nop; } 'd: {} } }",
  )
  guard stmt.desc is Dispatch(index~, cases~, default~, arms~)
  inspect(
    sketch_all(@ast.lower_dispatch(stmt.info, index~, cases~, default~, arms~)),
    content="block d[block b[block a[br_table[a,b,d](x)] nop] nop]",
  )
}

///|
test "match lowers to a threaded br_on_cast ladder" {
  // The scrutinee is read ONCE, at the bottom of the test chain; each test
  // branches out to its arm's block carrying the narrowed value. Arm i's body
  // sits in arm i+1's block, and the last one's in the escape block.
  let stmt = surface_stmt(
    "fn f(r: &any) { match r { &array => { nop; } null => { nop; } _ => {} } }",
  )
  guard stmt.desc is Match(scrutinee~, arms~, default~)
  let labels = []
  for i in 0..<(arms.length() + 1) {
    labels.push(fresh("#m\{i}"))
  }
  inspect(
    sketch_all(
      @ast.lower_match(stmt.info, labels~, scrutinee~, arms~, default~),
    ),
    // The `null` arm's block is VOID, so its result is not bound: only a cast
    // arm's block yields the narrowed value that the following `let` consumes.
    content="block #m2[block #m1[let _=block #m0[let _=br_on_null #m1(br_on_cast #m0(r)) br #m2] nop] nop]",
  )
}

///|
test "try/catch lowers to try_table inside a block ladder" {
  // One block per arm inside the join block, the try_table innermost, and each
  // arm body as trailing code -- so an arm's completion falls into the next
  // arm's, and the last one's out of the join.
  let r = @grammar.parse_string(
    "fn f() { 'j: try { nop; } catch { e => { nop; } _ => {} } }",
  )
  guard r.module_ is Some(fields)
  guard fields[0].desc is Func(body~, ..)
  let (_, stmts) = body
  guard stmts[0].desc is TryCatch(label~, typ~, block~, arms~)
  let arm_labels = []
  for i in 0..<arms.length() {
    arm_labels.push(fresh("#c\{i}"))
  }
  inspect(
    sketch(
      @ast.lower_trycatch(
        stmts[0].info,
        join=label.unwrap_or(fresh("#join")),
        arm_labels~,
        typ~,
        block~,
        arms~,
      ),
    ),
    // A void try leaves the try_table and the escaping branch side by side; a
    // value-producing one branches WITH the try_table's result instead.
    content="block j[block #c1[block #c0[? br j] nop]]",
  )
}

///|
test "map_info rebuilds the tree without disturbing it" {
  // The type checker's move -- `Instr[Location]` in, `Instr[T]` out -- so what
  // matters is that the shape survives. `sub_instrs` counts it.
  let r = @grammar.parse_string(
    "fn f(x: i32) -> i32 { if x { nop; } else { nop; } x + 1; }",
  )
  guard r.module_ is Some(fields)
  guard fields[0].desc is Func(body~, ..)
  let (_, stmts) = body
  let before = stmts.map(count).fold(init=0, (a, b) => a + b)
  let after = stmts
    .map(s => count(s.map_info(_ => 0)))
    .fold(init=0, (a, b) => a + b)
  inspect("\{before} \{after}", content="7 7")
}

///|
/// How many instructions there are in and under `i`.
fn[I] count(i : @ast.Instr[I]) -> Int {
  let mut n = 0
  i.iter_instr(_ => n = n + 1)
  n
}
