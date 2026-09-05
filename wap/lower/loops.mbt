// Loops, and the labels wap generates so you do not have to.
//
// A Wax loop needs a name to branch to; a wap loop does not. What follows is
// the whole of that difference: a frame per enclosing loop, a label minted the
// first time something jumps to it, and no enclosing block emitted when nothing
// breaks out.

///|
/// Push a loop frame and return the label a `continue` will use.
fn Lowering::enter_loop(
  self : Lowering,
  name : String?,
  stem : String,
) -> LoopFrame {
  let continue_label = match name {
    Some(n) => n
    None => self.gensym(stem)
  }
  let frame : LoopFrame = {
    name,
    continue_label,
    break_label: None,
    break_used: false,
    continue_used: false,
  }
  self.loops.push(frame)
  frame
}

///|
fn Lowering::leave_loop(self : Lowering) -> Unit {
  let _ = self.loops.pop()
}

///|
/// The frame a `break`/`continue` refers to.
fn Lowering::frame_for(self : Lowering, name : String?) -> LoopFrame? {
  match name {
    None =>
      if self.loops.length() == 0 {
        None
      } else {
        Some(self.loops[self.loops.length() - 1])
      }
    Some(n) => {
      for i = self.loops.length() - 1; i >= 0; i = i - 1 {
        if self.loops[i].name == Some(n) {
          return Some(self.loops[i])
        }
      }
      None
    }
  }
}

///|
/// `break` and `continue`, which are both a `br` once the label exists.
fn Lowering::jump(
  self : Lowering,
  name : String?,
  is_break : Bool,
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  match self.frame_for(name) {
    None => {
      self.error(
        if is_break {
          "`break` is not inside a loop"
        } else {
          "`continue` is not inside a loop"
        },
        sp,
      )
      @ast.build(Unreachable, at)
    }
    Some(f) =>
      if is_break {
        let label = match f.break_label {
          Some(l) => l
          None => {
            let l = self.gensym(f.continue_label + "__done")
            f.break_label = Some(l)
            l
          }
        }
        f.break_used = true
        @ast.build(Br(self.ident(label, sp), None), at)
      } else {
        f.continue_used = true
        @ast.build(Br(self.ident(f.continue_label, sp), None), at)
      }
  }
}

///|
/// Wrap a loop in the block a `break` branches out of, but only if one did.
fn Lowering::wrap_break(
  self : Lowering,
  f : LoopFrame,
  inner : @ast.Instr[@basic.Location],
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  if !f.break_used {
    return inner
  }
  let at = self.loc(sp)
  let label = match f.break_label {
    Some(l) => l
    None => self.gensym("done")
  }
  @ast.build(
    Block(label=Some(self.ident(label, sp)), typ=empty_type(), block={
      desc: [inner],
      info: at,
    }),
    at,
  )
}

///|
/// `while c ~step(s): body`
fn Lowering::while_loop(
  self : Lowering,
  label : String?,
  cond : @wap.Node,
  step : @wap.Node?,
  body : Array[@wap.Node],
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let f = self.enter_loop(label, "while")
  self.push_scope()
  let block = self.blk(body, sp)
  let c = self.expr(cond, None)
  let s = match step {
    Some(s) => Some(self.expr(s, None))
    None => None
  }
  self.pop_scope()
  self.leave_loop()
  // The loop's own label is emitted only when a `continue` used it.
  let lbl = if self.label_used(f) {
    Some(self.ident(f.continue_label, sp))
  } else {
    None
  }
  let w = @ast.build(While(label=lbl, cond=c, step=s, block~), at)
  self.wrap_break(f, w, sp)
}

///|
/// Whether the loop's own label was branched to.
///
/// A `continue` mints nothing -- the label already exists -- so this asks
/// whether the label was named, which the frame records by having been used at
/// all. Naming it always would be correct and would also emit labels nothing
/// refers to, which the printed expansion should not contain.
fn Lowering::label_used(self : Lowering, f : LoopFrame) -> Bool {
  ignore(self)
  f.name is Some(_) || f.break_used || f.continue_used
}

///|
/// `loop: body`
fn Lowering::plain_loop(
  self : Lowering,
  label : String?,
  body : Array[@wap.Node],
  sp : @wap.Span,
) -> @ast.Instr[@basic.Location] {
  let at = self.loc(sp)
  let f = self.enter_loop(label, "loop")
  self.push_scope()
  let block = self.blk(body, sp)
  self.pop_scope()
  // A wasm `loop` is a branch target, not a repetition: it runs once unless
  // something branches back to it. Wax makes you write that `br`; wap writes
  // it, which is the only reason `loop:` means what it looks like.
  block.desc.push(@ast.build(Br(self.ident(f.continue_label, sp), None), at))
  self.leave_loop()
  let l = @ast.build(
    Loop(label=Some(self.ident(f.continue_label, sp)), typ=empty_type(), block~),
    at,
  )
  self.wrap_break(f, l, sp)
}

///|
/// `for i in a .. b by n: body`
fn Lowering::for_range(
  self : Lowering,
  label : String?,
  var_ : String,
  from : @wap.Node,
  to : @wap.Node,
  inclusive : Bool,
  by : @wap.Node?,
  body : Array[@wap.Node],
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  let at = self.loc(sp)
  let ity = match self.type_of(from) {
    Some(t) => Some(t)
    None => self.type_of(to)
  }
  self.push_scope()
  match ity {
    Some(t) => self.bind(var_, t)
    None => self.bind(var_, I32)
  }
  let out = []
  // The counter.
  out.push(
    @ast.build(
      Let([(Some(self.ident(var_, sp)), None)], Some(self.expr(from, ity))),
      at,
    ),
  )
  // The limit is evaluated once, so a call in it is not re-run every step.
  let limit : @wap.Node = match to.it {
    Int(_) | Var(_) => to
    _ => {
      let n = self.gensym("n")
      match ity {
        Some(t) => self.bind(n, t)
        None => self.bind(n, I32)
      }
      out.push(
        @ast.build(
          Let(
            [(Some({ name: n, loc: self.fresh_loc(), }), None)],
            Some(self.expr(to, ity)),
          ),
          at,
        ),
      )
      { it: Var(n), span: sp, }
    }
  }
  let subject : @wap.Node = { it: Var(var_), span: sp, }
  let cond : @wap.Node = {
    it: Bin(if inclusive { Le } else { Lt }, subject, limit),
    span: sp,
  }
  let stride = match by {
    Some(b) => b
    None => ({ it: Int("1"), span: sp, } : @wap.Node)
  }
  let step : @wap.Node = {
    it: Assign(targets=[subject], op=OpSet(Add), value=stride),
    span: sp,
  }
  let f = self.enter_loop(label, "for")
  let block = self.blk(body, sp)
  let c = self.expr(cond, None)
  let s = self.expr(step, None)
  self.leave_loop()
  let lbl = if self.label_used(f) {
    Some(self.ident(f.continue_label, sp))
  } else {
    None
  }
  let w = @ast.build(While(label=lbl, cond=c, step=Some(s), block~), at)
  out.push(self.wrap_break(f, w, sp))
  self.pop_scope()
  out
}

///|
/// `for x in xs: body`
fn Lowering::for_in(
  self : Lowering,
  label : String?,
  var_ : String,
  seq : @wap.Node,
  body : Array[@wap.Node],
  sp : @wap.Span,
) -> Array[@ast.Instr[@basic.Location]] {
  let at = self.loc(sp)
  let stype = self.type_of(seq)
  let elem = match stype {
    Some(t) => self.elem_type(t)
    None => None
  }
  self.push_scope()
  let out = []
  // The sequence, bound once.
  let holder : @wap.Node = match seq.it {
    Var(_) => seq
    _ => {
      let s = self.gensym("seq")
      match stype {
        Some(t) => self.bind(s, t)
        None => ()
      }
      out.push(
        @ast.build(
          Let(
            [(Some({ name: s, loc: self.fresh_loc(), }), None)],
            Some(self.expr(seq, None)),
          ),
          at,
        ),
      )
      { it: Var(s), span: sp, }
    }
  }
  let idx = self.gensym("i")
  let len = self.gensym("n")
  self.bind(idx, U32)
  self.bind(len, U32)
  out.push(
    @ast.build(
      Let(
        [(Some({ name: idx, loc: self.fresh_loc(), }), None)],
        Some(@ast.build(Int("0"), at)),
      ),
      at,
    ),
  )
  out.push(
    @ast.build(
      Let(
        [(Some({ name: len, loc: self.fresh_loc(), }), None)],
        Some(
          @ast.build(
            Call(
              @ast.build(
                StructGet(self.expr(holder, None), self.ident("length", sp)),
                at,
              ),
              [],
            ),
            at,
          ),
        ),
      ),
      at,
    ),
  )
  let idx_node : @wap.Node = { it: Var(idx), span: sp, }
  let cond : @wap.Node = {
    it: Bin(Lt, idx_node, { it: Var(len), span: sp, }),
    span: sp,
  }
  let step : @wap.Node = {
    it: Assign(targets=[idx_node], op=OpSet(Add), value={
      it: Int("1"),
      span: sp,
    }),
    span: sp,
  }
  let f = self.enter_loop(label, "for")
  self.push_scope()
  match elem {
    Some(t) => self.bind(var_, t)
    None => ()
  }
  // The element, bound at the top of the body.
  let inner = [
    @ast.build(
      Let(
        [(Some(self.ident(var_, sp)), None)],
        Some(
          self.widen(
            @ast.build(
              ArrayGet(self.expr(holder, None), self.expr(idx_node, None)),
              at,
            ),
            elem,
            sp,
          ),
        ),
      ),
      at,
    ),
  ]
  for b in self.body(body) {
    inner.push(b)
  }
  self.pop_scope()
  let c = self.expr(cond, None)
  let s = self.expr(step, None)
  self.leave_loop()
  let lbl = if self.label_used(f) {
    Some(self.ident(f.continue_label, sp))
  } else {
    None
  }
  let w = @ast.build(
    While(label=lbl, cond=c, step=Some(s), block={ desc: inner, info: at, }),
    at,
  )
  out.push(self.wrap_break(f, w, sp))
  self.pop_scope()
  out
}
