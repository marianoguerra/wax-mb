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
  lower_program([{ module_: m, source: { fname, text, src, }, }])
}

///|
/// Lower a whole program -- several wap modules -- into one Wax module.
///
/// One wasm module comes out, with one flat namespace, because that is what
/// wasm has. What the module system does is decide the names in it: a
/// declaration in `hashing` is emitted as `hashing__name`, and a reference to
/// it from elsewhere is written `hashing.name`.
///
/// The modules must arrive in dependency order, which is what
/// `marianoguerra/wap/resolve` produces.
pub fn lower_program(units : Array[Input]) -> Lowered {
  let entry = if units.length() > 0 {
    units[units.length() - 1].source
  } else {
    ({ fname: "", text: "", src: 0, } : ModuleSource)
  }
  let l = Lowering::new("", entry~)
  for u in units {
    l.modules[u.module_.name] = ()
    l.line_maps[u.module_.name] = LineMap::of(u.source)
  }
  // Types first, across every module: a module may name another's types
  // regardless of which was declared first.
  for u in units {
    l.enter(u.module_.name)
    l.collect_types(u.module_)
  }
  for u in units {
    l.enter(u.module_.name)
    l.collect_rest(u.module_)
  }
  let fields : @ast.LocModule = []
  for u in units {
    l.enter(u.module_.name)
    for f in l.emit(u.module_) {
      fields.push(f)
    }
  }
  // The generated types are shared by the whole program.
  if l.extra_types.length() > 0 {
    let at = l.extra_types[0].info
    fields.push({ desc: Type(l.extra_types), info: at, })
  }
  { fields, diagnostics: l.diagnostics, }
}

// ------------------------------------------------------------------ pass 1

///|
/// Record what every declaration introduces, so that the order they were
/// written in does not matter.
fn Lowering::collect_types(self : Lowering, m : @wap.Module) -> Unit {
  let seen : Map[String, Unit] = Map([])
  for d in m.decls {
    match d {
      Import(path) => {
        // The alias is the module's own declared name, not the path.
        let last = path[path.length() - 1]
        seen[last] = ()
      }
      _ => ()
    }
  }
  self.imports[m.name] = seen
  for d in m.decls {
    match d {
      TypeD(name~, def~, is_pub~, ..) => {
        let q = self.qualify(name)
        self.types[q] = self.qualify_def(def)
        if is_pub {
          self.visible[q] = ()
        }
        if def is Enum(items) {
          let ms : Map[String, Int] = Map([])
          for it in items {
            let (n, v) = it
            let qn = self.qualify(n)
            ms[n] = v.unwrap_or(0)
            if self.member_owner.contains(qn) {
              self.member_owner.remove(qn)
            } else {
              self.member_owner[qn] = q
            }
            if is_pub {
              self.visible[qn] = ()
            }
          }
          self.enum_members[q] = ms
        }
      }
      _ => ()
    }
  }
}

///|
/// Everything a module declares that is not a type.
fn Lowering::collect_rest(self : Lowering, m : @wap.Module) -> Unit {
  for d in m.decls {
    match d {
      Const(c) => {
        if c.import_name is Some(_) {
          self.foreign[c.name] = ()
        }
        self.globals[self.qualify(c.name)] = self.qualify_typ(
          c.typ.unwrap_or(I32),
        )
        if c.is_pub {
          self.visible[self.qualify(c.name)] = ()
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
      Impl(typ~, methods~, ..) => {
        let q = self.qualify(typ)
        for f in methods {
          let sig : FnSig = {
            params: f.params.map(p => self.qualify_typ(p.typ)),
            results: f.results.map(t => self.qualify_typ(t)),
            emitted: self.mangle_method(typ, f.name),
          }
          self.methods[q + "." + f.name] = sig
          match self.method_owners.get(f.name) {
            Some(a) => a.push(q)
            None => self.method_owners[f.name] = [q]
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn Lowering::note_fn(self : Lowering, f : @wap.FnDecl, foreign : Bool) -> Unit {
  let emitted = if foreign { f.name } else { self.mangle(f.name) }
  let key = if foreign { f.name } else { self.qualify(f.name) }
  self.funcs[key] = {
    params: f.params.map(p => self.qualify_typ(p.typ)),
    results: f.results.map(t => self.qualify_typ(t)),
    emitted,
  }
  if f.is_pub {
    self.visible[key] = ()
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
      TypeD(name~, def~, span~, ..) =>
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
            final_: !parents.contains(self.qualify(name)),
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
  let q = self.qualify(typ)
  for name, def in self.types {
    if def is Record(parent=Some(p), ..) &&
      p == q &&
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
