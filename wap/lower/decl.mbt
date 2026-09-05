// Declarations, and the entry point.

///|
/// A lowered module: Wax AST, plus whatever went wrong producing it.
pub struct Lowered {
  fields : @ast.LocModule
  diagnostics : Array[@er.Report]
}

///|
/// The Wax module fields.
pub fn Lowered::fields(self : Self) -> @ast.LocModule {
  self.fields
}

///|
/// Problems found while lowering. Wax's own checker runs afterwards and adds
/// its own.
pub fn Lowered::diagnostics(self : Self) -> Array[@er.Report] {
  self.diagnostics
}

///|
/// Lower a wap module to Wax AST.
///
/// `text` is the source the spans index into, so that a Wax type error lands on
/// the wap line that caused it. A generator with no source passes `""` and gets
/// synthetic locations.
pub fn lower_module(
  m : @wap.Module,
  text? : String = "",
  fname? : String = "input.wap",
  src? : @er.SourceId = 0,
) -> Lowered {
  let l = Lowering::new(m.name, fname~, text~, src~)
  l.collect(m)
  let fields = l.emit(m)
  { fields, diagnostics: l.diagnostics, }
}

// ------------------------------------------------------------------ pass 1

///|
/// Record what every declaration introduces, so that the order they were
/// written in does not matter.
fn Lowering::collect(self : Lowering, m : @wap.Module) -> Unit {
  for d in m.decls {
    match d {
      TypeD(name~, def~, ..) => {
        self.types[name] = def
        if def is Enum(items) {
          let ms : Map[String, Int] = Map([])
          for it in items {
            let (n, v) = it
            ms[n] = v.unwrap_or(0)
            if self.member_owner.contains(n) {
              // Two enumerations with the same member name: the bare name is
              // no longer usable, so record neither.
              self.member_owner.remove(n)
            } else {
              self.member_owner[n] = name
            }
          }
          self.enum_members[name] = ms
        }
      }
      _ => ()
    }
  }
  for d in m.decls {
    match d {
      Const(c) => {
        self.globals[c.name] = c.typ.unwrap_or(I32)
        if c.import_name is Some(_) {
          self.foreign[c.name] = ()
        }
      }
      Fn(f) => self.note_fn(f, false)
      ImportWas(funcs~, consts~, ..) => {
        for f in funcs {
          self.foreign[f.name] = ()
          self.note_fn(f, true)
        }
        for c in consts {
          self.foreign[c.name] = ()
          self.globals[c.name] = c.typ.unwrap_or(I32)
        }
      }
      ImportHost(funcs~, consts~, ..) => {
        for f in funcs {
          self.note_fn(f, false)
        }
        for c in consts {
          self.globals[c.name] = c.typ.unwrap_or(I32)
        }
      }
      Impl(typ~, methods~, ..) =>
        for f in methods {
          let sig : FnSig = {
            params: f.params.map(p => p.typ),
            results: f.results,
            emitted: self.mangle_method(typ, f.name),
          }
          self.methods[typ + "." + f.name] = sig
          match self.method_owners.get(f.name) {
            Some(a) => a.push(typ)
            None => self.method_owners[f.name] = [typ]
          }
        }
      _ => ()
    }
  }
}

///|
fn Lowering::note_fn(self : Lowering, f : @wap.FnDecl, foreign : Bool) -> Unit {
  let emitted = if foreign { f.name } else { self.mangle(f.name) }
  self.funcs[f.name] = {
    params: f.params.map(p => p.typ),
    results: f.results,
    emitted,
  }
}

// ------------------------------------------------------------------ pass 2

///|
fn Lowering::emit(self : Lowering, m : @wap.Module) -> @ast.LocModule {
  let out : @ast.LocModule = []
  let parents = self.parents()
  // Nominal types, in one recursive group so that declaration order in the
  // source does not constrain the types that refer to each other.
  let group : Array[
    @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location],
  ] = []
  for d in m.decls {
    match d {
      TypeD(name~, def~, span~) =>
        match self.type_decl(name, def, span, parents) {
          Some(entry) => group.push(entry)
          None => ()
        }
      _ => ()
    }
  }
  for d in m.decls {
    match d {
      Const(c) => out.push(self.const_field(c))
      Fn(f) => if f.body is Some(_) { out.push(self.func_field(f, None)) }
      Impl(typ~, methods~, ..) => {
        for f in methods {
          if f.body is Some(_) {
            out.push(self.func_field(f, Some(typ)))
          }
        }
        for f in methods {
          match self.dispatcher(typ, f) {
            Some(field) => out.push(field)
            None => ()
          }
        }
      }
      ImportHost(module_~, funcs~, consts~) =>
        out.push(self.import_group(module_, funcs, consts))
      // `import was` and `import module` produce nothing: the first is a
      // signature for a name the emitted module already has, the second is a
      // visibility statement resolved before this point.
      _ => ()
    }
  }
  for extra in self.extra_types {
    group.push(extra)
  }
  if group.length() > 0 {
    let at = group[0].info
    out.insert(
      0,
      (
        { desc: Type(group), info: at, } :
        @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]),
    )
  }
  out
}

///|
/// One nominal type declaration, or nothing when the name is transparent.
fn Lowering::type_decl(
  self : Lowering,
  name : String,
  def : @wap.TypeDef,
  span : @wap.Span,
  parents : Map[String, Unit],
) -> @basic.Annotated[(@ast.Ident, @ast.SubType), @basic.Location]? {
  let at = self.loc(span)
  let id = self.ident(self.mangle(name), span)
  match def {
    Record(parent~, fields~) => {
      let fs : Array[
        @basic.Annotated[
          (@ast.Ident, @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
          @basic.Location,
        ],
      ] = []
      // A child repeats its parent's fields with `..`, which is Wax's spelling
      // and keeps the field order the supertype requires.
      if parent is Some(_) {
        fs.push(@ast.splice_field(at))
      }
      for f in fields {
        fs.push({
          desc: (
            self.ident(f.name, f.span),
            (
              { mut_: f.mut_, typ: self.storage(f.typ, f.span), } :
              @wasm_types.MutType[@wasm_types.StorageType[@ast.Ident]]),
          ),
          info: self.loc(f.span),
        })
      }
      Some({
        desc: (
          id,
          {
            typ: Struct(fs),
            supertype: match parent {
              Some(p) => Some(self.ident(self.mangle(p), span))
              None => None
            },
            final_: !parents.contains(name),
            descriptor: None,
            describes: None,
          },
        ),
        info: at,
      })
    }
    Alias(ArrayOf(e)) =>
      Some({
        desc: (
          id,
          {
            typ: Array({ mut_: true, typ: self.storage(e, span), }),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: at,
      })
    Alias(Func(params~, results~)) => {
      let ps = []
      for t in params {
        ps.push(
          (
            { desc: (None, self.valtype(t, span)), info: at, } :
            @basic.Annotated[
              (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
              @basic.Location,
            ]),
        )
      }
      let rs = []
      for t in results {
        rs.push(self.valtype(t, span))
      }
      Some({
        desc: (
          id,
          {
            typ: Func({ params: ps, results: rs, }),
            supertype: None,
            final_: true,
            descriptor: None,
            describes: None,
          },
        ),
        info: at,
      })
    }
    _ => None
  }
}

///|
fn Lowering::const_field(
  self : Lowering,
  c : @wap.ConstDecl,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  let at = self.loc(c.span)
  let attrs = []
  match c.export_name {
    Some(n) => attrs.push(@build.exported(name=n, at~))
    None => ()
  }
  {
    desc: Global(
      name=self.ident(self.mangle(c.name), c.span),
      mut_=false,
      typ=match c.typ {
        Some(t) => Some(self.valtype(t, c.span))
        None => None
      },
      def=self.expr(c.value, c.typ),
      attributes=attrs,
    ),
    info: at,
  }
}

///|
fn Lowering::func_field(
  self : Lowering,
  f : @wap.FnDecl,
  receiver : String?,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  let at = self.loc(f.span)
  let name = match receiver {
    Some(r) => self.mangle_method(r, f.name)
    None => self.mangle(f.name)
  }
  let attrs = []
  match f.export_name {
    Some(n) => attrs.push(@build.exported(name=n, at~))
    None => ()
  }
  if f.is_start {
    attrs.push(
      (
        {
          attr_name: "start",
          attr_value: None,
          attr_guard: None,
          attr_span: at,
        } : @ast.Attribute),
    )
  }
  self.push_scope()
  for p in f.params {
    self.bind(p.name, p.typ)
  }
  let body = match f.body {
    Some(b) => self.body(b)
    None => []
  }
  self.pop_scope()
  {
    desc: Func(
      name=self.ident(name, f.span),
      typ=None,
      sign=Some(self.signature(f)),
      body=(None, body),
      attributes=attrs,
    ),
    info: at,
  }
}

///|
fn Lowering::signature(self : Lowering, f : @wap.FnDecl) -> @ast.FuncType {
  let ps = []
  for p in f.params {
    ps.push(
      (
        {
          desc: (Some(self.ident(p.name, p.span)), self.valtype(p.typ, p.span)),
          info: self.loc(p.span),
        } :
        @basic.Annotated[
          (@ast.Ident?, @wasm_types.ValType[@ast.Ident]),
          @basic.Location,
        ]),
    )
  }
  let rs = []
  for t in f.results {
    match t {
      Tuple(items) =>
        for it in items {
          rs.push(self.valtype(it, f.span))
        }
      _ => rs.push(self.valtype(t, f.span))
    }
  }
  { params: ps, results: rs, }
}

///|
/// The dispatcher for a method that subtypes override.
///
/// Wap does not build a vtable: that needs custom descriptors, and a feature
/// behind a feature flag is a feature you write in was. This is a type switch,
/// which Wax already has, and which is correct for a hierarchy that is closed
/// -- and inside one wasm module every hierarchy is.
fn Lowering::dispatcher(
  self : Lowering,
  typ : String,
  f : @wap.FnDecl,
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location]? {
  let subs = []
  for name, def in self.types {
    if def is Record(parent=Some(p), ..) &&
      p == typ &&
      self.methods.contains(name + "." + f.name) {
      subs.push(name)
    }
  }
  if subs.length() == 0 {
    return None
  }
  let sp = f.span
  let at = self.loc(sp)
  let self_name = if f.params.length() > 0 { f.params[0].name } else { "self" }
  let arms : Array[
    (
      @ast.MatchPattern,
      @basic.Annotated[Array[@ast.Instr[@basic.Location]], @basic.Location],
    ),
  ] = []
  for sub in subs {
    let v = self.valtype(Named(sub), sp)
    let rt = match v {
      Ref(r) => r
      _ => ({ nullable: false, typ: Any, } : @wasm_types.RefType[@ast.Ident])
    }
    let bound = self.gensym("d")
    let call_args = [@ast.build(Get(self.ident(bound, sp)), at)]
    for i, p in f.params {
      if i > 0 {
        call_args.push(@ast.build(Get(self.ident(p.name, sp)), at))
      }
    }
    arms.push(
      (
        MatchCast(Some({ name: bound, loc: self.fresh_loc(), }), rt),
        {
          desc: [
            @ast.build(
              Return(
                Some(
                  @ast.build(
                    Call(
                      @ast.build(
                        Get(self.ident(self.mangle_method(sub, f.name), sp)),
                        at,
                      ),
                      call_args,
                    ),
                    at,
                  ),
                ),
              ),
              at,
            ),
          ],
          info: at,
        },
      ),
    )
  }
  let base_args = []
  for p in f.params {
    base_args.push(@ast.build(Get(self.ident(p.name, sp)), at))
  }
  let default : @basic.Annotated[
    Array[@ast.Instr[@basic.Location]],
    @basic.Location,
  ] = {
    desc: [
      @ast.build(
        Return(
          Some(
            @ast.build(
              Call(
                @ast.build(
                  Get(self.ident(self.mangle_method(typ, f.name), sp)),
                  at,
                ),
                base_args,
              ),
              at,
            ),
          ),
        ),
        at,
      ),
    ],
    info: at,
  }
  let body = [
    @ast.build(
      Match(
        scrutinee=@ast.build(Get(self.ident(self_name, sp)), at),
        arms~,
        default~,
      ),
      at,
    ),
  ]
  Some({
    desc: Func(
      name=self.ident(self.mangle_method(typ, f.name + "__dyn"), sp),
      typ=None,
      sign=Some(self.signature(f)),
      body=(None, body),
      attributes=[],
    ),
    info: at,
  })
}

///|
fn Lowering::import_group(
  self : Lowering,
  module_ : String,
  funcs : Array[@wap.FnDecl],
  consts : Array[@wap.ConstDecl],
) -> @basic.Annotated[@ast.ModuleField[@basic.Location], @basic.Location] {
  let at = self.fresh_loc()
  let decls : Array[@basic.Annotated[@ast.ImportDecl, @basic.Location]] = []
  for f in funcs {
    let attrs = []
    match f.import_name {
      Some(n) => attrs.push(@build.import_as(n, at=self.loc(f.span)))
      None => ()
    }
    decls.push({
      desc: {
        id: self.ident(self.mangle(f.name), f.span),
        kind: Func(typ=None, sign=Some(self.signature(f)), exact=false),
        attributes: attrs,
      },
      info: self.loc(f.span),
    })
  }
  for c in consts {
    let attrs = []
    match c.import_name {
      Some(n) => attrs.push(@build.import_as(n, at=self.loc(c.span)))
      None => ()
    }
    decls.push({
      desc: {
        id: self.ident(self.mangle(c.name), c.span),
        kind: Global(mut_=false, typ=self.valtype(c.typ.unwrap_or(I32), c.span)),
        attributes: attrs,
      },
      info: self.loc(c.span),
    })
  }
  {
    desc: ImportGroup(
      module_={ desc: @utf8.encode(module_), info: at, },
      decls~,
    ),
    info: at,
  }
}
