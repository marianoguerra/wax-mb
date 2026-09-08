///|
fn n(it : @w.Expr) -> @w.Node {
  { it, span: @w.nowhere, }
}

///|
fn v(name : String) -> @w.Node {
  n(Var(name))
}

///|
fn i(value : Int) -> @w.Node {
  n(Int(value.to_string()))
}

///|
fn call(name : String, args : Array[@w.Node]) -> @w.Node {
  n(Call(v(name), args))
}

///|
fn bind(name : String, value : @w.Node, typ : @w.Type) -> @w.Node {
  n(
    Bind(
      binders=[{ name, typ: Some(typ), span: @w.nowhere, }],
      value=Some(value),
      mutable=false,
    ),
  )
}

///|
fn field(value : @w.Node, name : String) -> @w.Node {
  n(Field(value, name))
}

///|
// Wax Sequence is a multi-value tuple, not an expression block. A typed if
// provides the lexical instruction scope needed by generated value blocks.
fn block(body : Array[@w.Node], typ : @w.Type) -> @w.Node {
  n(
    If(
      arms=[(Some(n(BoolLit(true))), body), (None, [n(Unreachable)])],
      typ=Some(typ),
    ),
  )
}

///|
fn function_decl(
  name : String,
  params : Array[(String, @w.Type)],
  result : @w.Type,
  body : Array[@w.Node],
  export_name? : String,
) -> @w.Decl {
  Fn({
    name,
    receiver: None,
    params: params.map(p => { name: p.0, typ: p.1, span: @w.nowhere, }),
    results: [result],
    body: Some(body),
    export_name,
    import_name: None,
    is_start: false,
    is_pub: false,
    span: @w.nowhere,
  })
}

///|
priv struct Generator {
  decls : Array[@w.Decl]
  functions : Map[String, Function]
  records : Map[String, Record]
  aliases : Map[String, String]
  requirements : Map[String, String]
  sources : Map[String, Int]
  mut counter : Int
  mut module_ : String
}

///|
fn Generator::fresh(self : Generator) -> String {
  self.counter += 1
  "s_" + self.counter.to_string()
}

///|
fn mangled(s : String) -> String {
  "user_" + s.replace_all(old="_", new="__").replace_all(old=".", new="_d")
}

///|
fn Generator::array(self : Generator, items : Array[@w.Node]) -> @w.Node {
  let name = self.fresh()
  let body = [
    bind(
      name,
      call("values_new", [v("ctx"), i(items.length())]),
      Named("values"),
    ),
  ]
  for j, item in items {
    body.push(n(Assign(targets=[n(Index(v(name), i(j)))], op=Set, value=item)))
  }
  body.push(v(name))
  block(body, Named("values"))
}

///|
fn Generator::text(self : Generator, text : String) -> @w.Node {
  let bytes = @utf8.encode(text)
  let name = self.fresh()
  let body = [
    bind(name, call("bytes_new", [v("ctx"), i(bytes.length())]), Named("bytes")),
  ]
  for j in 0..<bytes.length() {
    body.push(
      n(
        Assign(
          targets=[n(Index(v(name), i(j)))],
          op=Set,
          value=i(bytes[j].to_int()),
        ),
      ),
    )
  }
  body.push(v(name))
  block(body, Named("bytes"))
}

///|
fn Generator::keyword(self : Generator, name : String) -> @w.Node {
  call("string", [v("ctx"), self.text(name), n(BoolLit(true))])
}

///|
fn Generator::resolve(self : Generator, name : String) -> String {
  self.aliases
  .get(self.module_ + ":" + name)
  .unwrap_or(self.module_ + "." + name)
}

///|
fn path(term : Term) -> String? {
  match term.expr {
    Name(s) => Some(s)
    Field(parent, s) => path(parent).map(p => p + "." + s)
    _ => None
  }
}

///|
fn builtin_id(name : String) -> Int? {
  let names = [
    "list", "set", "count", "get", "assoc", "conj", "not", "map", "filter", "reduce",
    "first", "rest", "contains", "into", "float", "integer", "dissoc", "hash",
  ]
  for i, n in names {
    if n == name {
      return Some(i)
    }
  }
  None
}

///|
fn referenced(
  term : Term,
  bound : Map[String, Bool],
  names : Map[String, Bool],
) -> Unit {
  match term.expr {
    Name(s) => if !bound.contains(s) { names[s] = true }
    Call(f, args) => {
      referenced(f, bound, names)
      for a in args {
        referenced(a, bound, names)
      }
    }
    Field(a, _) => referenced(a, bound, names)
    Binary(_, a, b) => {
      referenced(a, bound, names)
      referenced(b, bound, names)
    }
    Vector(xs) =>
      for x in xs {
        referenced(x, bound, names)
      }
    MapLit(xs) =>
      for pair in xs {
        let (a, b) = pair
        referenced(a, bound, names)
        referenced(b, bound, names)
      }
    Lambda(params, body) => {
      let scope = bound.copy()
      for p in params {
        scope[p] = true
      }
      referenced_body(body, scope, names)
    }
    Bind(_, x) => referenced(x, bound, names)
    If(x, a, b) => {
      referenced(x, bound, names)
      referenced_body(a, bound.copy(), names)
      referenced_body(b, bound.copy(), names)
    }
    Match(x, arms) => {
      referenced(x, bound, names)
      for pair in arms {
        let scope = bound.copy()
        pattern_names(pair.0, scope)
        referenced_body(pair.1, scope, names)
      }
    }
    _ => ()
  }
}

///|
fn pattern_names(pattern : Term, names : Map[String, Bool]) -> Unit {
  match pattern.expr {
    Name(s) => names[s] = true
    Call(_, args) | Vector(args) =>
      for a in args {
        pattern_names(a, names)
      }
    _ => ()
  }
}

///|
fn referenced_body(
  body : Array[Term],
  bound : Map[String, Bool],
  names : Map[String, Bool],
) -> Unit {
  for term in body {
    referenced(term, bound, names)
    if term.expr is Bind(bindings, _) {
      for b in bindings {
        bound[b] = true
      }
    }
  }
}

///|
fn Generator::lambda(
  self : Generator,
  params : Array[String],
  body : Array[Term],
  env : Map[String, @w.Node],
) -> @w.Node raise ScriptError {
  let name = self.fresh()
  let captures = []
  let used : Map[String, Bool] = Map([])
  let bound : Map[String, Bool] = Map([])
  for p in params {
    bound[p] = true
  }
  referenced_body(body, bound, used)
  for k in env.keys() {
    if used.contains(k) && !params.contains(k) {
      captures.push(k)
    }
  }
  captures.sort()
  let inner : Map[String, @w.Node] = Map([])
  for j, key in captures {
    inner[key] = n(Index(n(Cast(v("env"), Named("values"))), i(j)))
  }
  self.emit_function(name, params, body, inner)
  call("function", [v("ctx"), v(name), self.array(captures.map(k => env[k]))])
}

///|
fn Generator::emit_function(
  self : Generator,
  name : String,
  params : Array[String],
  body : Array[Term],
  env : Map[String, @w.Node],
) -> Unit raise ScriptError {
  let prefix = [
    call("tick", [v("ctx"), n(Int("1"))]),
    call("arity", [v("ctx"), v("args"), i(params.length())]),
  ]
  for j, p in params {
    let binding = self.fresh()
    prefix.push(bind(binding, n(Index(v("args"), i(j))), Nullable(Eq)))
    env[p] = v(binding)
  }
  prefix.append(self.body(body, env, true))
  self.decls.push(
    function_decl(
      name,
      [
        ("ctx", Named("context")),
        ("env", Nullable(Eq)),
        ("args", Named("values")),
      ],
      Nullable(Eq),
      prefix,
    ),
  )
}

///|
fn Generator::body(
  self : Generator,
  body : Array[Term],
  env : Map[String, @w.Node],
  tail : Bool,
) -> Array[@w.Node] raise ScriptError {
  let out = []
  for j, term in body {
    if term.expr is Bind(names, rhs) {
      let name = self.fresh()
      out.push(bind(name, self.expr(rhs, env, false), Nullable(Eq)))
      if names.length() == 1 {
        env[names[0]] = v(name)
      } else {
        for k, binding in names {
          let temp = self.fresh()
          out.push(
            bind(
              temp,
              call("get", [
                v("ctx"),
                v(name),
                call("int", [v("ctx"), n(Int(k.to_string()))]),
                n(Null),
              ]),
              Nullable(Eq),
            ),
          )
          env[binding] = v(temp)
        }
      }
      if j == body.length() - 1 {
        out.push(n(Null))
      }
    } else {
      let value = self.expr(term, env, tail && j == body.length() - 1)
      out.push(if j == body.length() - 1 { value } else { n(Drop(value)) })
    }
  }
  out
}

///|
fn Generator::invoke(
  self : Generator,
  target : @w.Node,
  args : Array[@w.Node],
  tail : Bool,
) -> @w.Node {
  if tail {
    return n(TailCall(target, args))
  }
  let temp = self.fresh()
  block(
    [
      call("enter", [v("ctx")]),
      bind(temp, n(Call(target, args)), Nullable(Eq)),
      call("leave", [v("ctx")]),
      v(temp),
    ],
    Nullable(Eq),
  )
}

///|
fn Generator::expr(
  self : Generator,
  t : Term,
  env : Map[String, @w.Node],
  tail : Bool,
) -> @w.Node raise ScriptError {
  let value = match t.expr {
    Nil => n(Null)
    Boolean(b) => call("bool", [v("ctx"), n(BoolLit(b))])
    Integer(s) => call("int", [v("ctx"), n(Int(s))])
    Float(s) => call("float", [v("ctx"), n(Float(s))])
    Text(s, keyword) =>
      call("string", [v("ctx"), self.text(s), n(BoolLit(keyword))])
    Name(name) =>
      match env.get(name) {
        Some(binding) => binding
        None => {
          let resolved = self.resolve(name)
          if self.functions.contains(resolved) {
            call("function", [v("ctx"), v(mangled(resolved)), n(Null)])
          } else if builtin_id(name) is Some(id) {
            let wrapper = "builtin_" + id.to_string()
            call("function", [v("ctx"), v(wrapper), n(Null)])
          } else {
            problem("unbound name " + name, t.span)
          }
        }
      }
    Vector(xs) =>
      call("seq", [
        v("ctx"),
        i(6),
        self.array(xs.map(x => self.expr(x, env, false))),
      ])
    MapLit(xs) => {
      let temp = self.fresh()
      let out = [
        bind(temp, call("seq", [v("ctx"), i(8), self.array([])]), Nullable(Eq)),
      ]
      let mut last = temp
      for pair in xs {
        let (key, value) = pair
        let next = self.fresh()
        out.push(
          bind(
            next,
            call("assoc", [
              v("ctx"),
              v(last),
              self.expr(key, env, false),
              self.expr(value, env, false),
            ]),
            Nullable(Eq),
          ),
        )
        last = next
      }
      out.push(v(last))
      block(out, Nullable(Eq))
    }
    Lambda(params, body) => self.lambda(params, body, env)
    Bind(_, _) => problem("let is only allowed in a body", t.span)
    If(condition, yes, no) =>
      n(
        If(
          arms=[
            (
              Some(call("truth", [self.expr(condition, env, false)])),
              self.body(yes, env.copy(), tail),
            ),
            (None, self.body(no, env.copy(), tail)),
          ],
          typ=Some(Nullable(Eq)),
        ),
      )
    Match(subject, patterns) => {
      let temp = self.fresh()
      let arms = []
      for pair in patterns {
        let scope = env.copy()
        let check = self.pattern(pair.0, v(temp), scope)
        arms.push((Some(check), self.body(pair.1, scope, tail)))
      }
      arms.push((None, [call("die", [v("ctx"), i(11)]), n(Unreachable)]))
      block(
        [
          bind(temp, self.expr(subject, env, false), Nullable(Eq)),
          n(If(arms~, typ=Some(Nullable(Eq)))),
        ],
        Nullable(Eq),
      )
    }
    Binary(op, a, b) =>
      if op == "and" || op == "or" {
        let temp = self.fresh()
        let condition = call("truth", [v(temp)])
        let right = self.expr(b, env, tail)
        block(
          [
            bind(temp, self.expr(a, env, false), Nullable(Eq)),
            n(
              If(
                arms=[
                  (Some(condition), [if op == "and" { right } else { v(temp) }]),
                  (None, [if op == "and" { v(temp) } else { right }]),
                ],
                typ=Some(Nullable(Eq)),
              ),
            ),
          ],
          Nullable(Eq),
        )
      } else {
        let ops = ["+", "-", "*", "/", "%", "==", "!=", "<", "<=", ">", ">="]
        let mut index = 0
        for j, x in ops {
          if x == op {
            index = j
          }
        }
        call("binary", [
          v("ctx"),
          i(index),
          self.expr(a, env, false),
          self.expr(b, env, false),
        ])
      }
    Field(parent, name) => {
      let qualified = path(t).map(s => self.resolve(s))
      let shadowed = path(t)
        .map(s => env.contains(s.split(".").next().unwrap_or("").to_owned()))
        .unwrap_or(false)
      if !shadowed && qualified is Some(q) && self.functions.contains(q) {
        call("function", [v("ctx"), v(mangled(q)), n(Null)])
      } else {
        call("get", [
          v("ctx"),
          self.expr(parent, env, false),
          self.keyword(name),
          n(Null),
        ])
      }
    }
    Call(f, args) => {
      let pname = path(f)
      let direct = pname.map(s => self.resolve(s))
      let root_local = match pname {
        Some(s) => env.contains(s.split(".").next().unwrap_or("").to_owned())
        None => false
      }
      if !root_local && direct is Some(q) && self.records.get(q) is Some(record) {
        if args.length() != record.fields.length() {
          problem("wrong constructor arity", t.span)
        }
        self.record(q, record, args, env)
      } else if !root_local &&
        direct is Some(q) &&
        self.functions.get(q) is Some(fun) {
        if args.length() != fun.params.length() {
          problem("wrong function arity", t.span)
        }
        self.invoke(
          v(mangled(q)),
          [
            v("ctx"),
            n(Null),
            self.array(args.map(a => self.expr(a, env, false))),
          ],
          tail,
        )
      } else if f.expr is Name(s) &&
        !env.contains(s) &&
        builtin_id(s) is Some(id) {
        self.invoke(
          v("builtin_" + id.to_string()),
          [
            v("ctx"),
            n(Null),
            self.array(args.map(a => self.expr(a, env, false))),
          ],
          tail,
        )
      } else {
        let callee = if f.expr is Field(parent, name) {
          // The runtime distinguishes a capability method from a record field.
          call("member", [
            v("ctx"),
            self.expr(parent, env, false),
            self.text(name),
          ])
        } else {
          self.expr(f, env, false)
        }
        let tmp = self.fresh()
        block(
          [
            bind(tmp, callee, Nullable(Eq)),
            self.invoke(
              v("apply"),
              [
                v("ctx"),
                v(tmp),
                self.array(args.map(a => self.expr(a, env, false))),
              ],
              tail,
            ),
          ],
          Nullable(Eq),
        )
      }
    }
  }
  // Fault locations are invocation-binding. Binding identities remain synthetic.
  block(
    [
      n(
        Assign(
          targets=[field(v("ctx"), "source")],
          op=Set,
          value=i(self.sources.get(self.module_).unwrap_or(0)),
        ),
      ),
      n(
        Assign(
          targets=[field(v("ctx"), "offset")],
          op=Set,
          value=i(t.span.start),
        ),
      ),
      { ..value, span: t.span, },
    ],
    Nullable(Eq),
  )
}

///|
fn Generator::pattern(
  self : Generator,
  pattern : Term,
  value : @w.Node,
  env : Map[String, @w.Node],
) -> @w.Node raise ScriptError {
  match pattern.expr {
    Name("_") => n(BoolLit(true))
    Name(s) => {
      env[s] = value
      n(BoolLit(true))
    }
    Call(ctor, fields) => {
      let name = match path(ctor) {
        Some(s) => self.resolve(s)
        None => problem("expected a constructor pattern", pattern.span)
      }
      let record = match self.records.get(name) {
        Some(r) => r
        None => problem("unknown constructor in pattern", pattern.span)
      }
      if fields.length() != record.fields.length() {
        problem("wrong pattern arity", pattern.span)
      }
      let mut check = n(Test(value, Named(mangled(name))))
      for j, p in fields {
        let item = n(
          Index(field(n(Cast(value, Named("record_value"))), "data"), i(j)),
        )
        check = n(AndAlso(check, self.pattern(p, item, env)))
      }
      check
    }
    Vector(fields) => {
      let k = call("kind", [value])
      let mut check = n(OrElse(n(Bin(Eq, k, i(6))), n(Bin(Eq, k, i(7)))))
      check = n(
        AndAlso(
          check,
          n(Bin(Eq, call("count", [v("ctx"), value]), i(fields.length()))),
        ),
      )
      for j, p in fields {
        let item = call("get", [
          v("ctx"),
          value,
          call("int", [v("ctx"), n(Int(j.to_string()))]),
          n(Null),
        ])
        check = n(AndAlso(check, self.pattern(p, item, env)))
      }
      check
    }
    Nil | Boolean(_) | Integer(_) | Float(_) | Text(_, _) =>
      call("equal", [v("ctx"), value, self.expr(pattern, env, false)])
    _ => problem("unsupported pattern", pattern.span)
  }
}

///|
fn Generator::record(
  self : Generator,
  name : String,
  record : Record,
  args : Array[Term],
  env : Map[String, @w.Node],
) -> @w.Node raise ScriptError {
  let out = []
  let fields : Array[(String, @w.Node?)] = [
    ("kind", Some(i(13))),
    ("name", Some(self.text(name))),
    ("keys", Some(self.array(record.fields.map(f => self.keyword(f.0))))),
  ]
  let data = []
  for j, arg in args {
    let binding = self.fresh()
    out.push(bind(binding, self.expr(arg, env, false), Nullable(Eq)))
    data.push(v(binding))
    let typ = record.fields[j].1
    let typed = match typ {
      "value" => v(binding)
      "i64" => call("int_value", [v("ctx"), v(binding)])
      "f64" => call("float_value", [v("ctx"), v(binding)])
      "bool" => call("checked_bool", [v("ctx"), v(binding)])
      _ => n(Cast(v(binding), self.storage_type(typ)))
    }
    fields.push(("slot_" + j.to_string(), Some(typed)))
  }
  fields.push(("data", Some(self.array(data))))
  out.push(call("allocate", [v("ctx"), i(fields.length()), n(Int("8"))]))
  out.push(n(RecordLit(typ=Some(mangled(name)), fields~)))
  block(out, Nullable(Eq))
}

///|
fn Generator::storage_type(
  self : Generator,
  name : String,
) -> @w.Type raise ScriptError {
  match name {
    "value" => Nullable(Eq)
    "i64" => I64
    "f64" => F64
    "bool" => Bool
    _ => {
      if name.has_suffix("?") {
        return Nullable(self.storage_type(name[:name.length() - 1].to_owned()))
      }
      let resolved = self.resolve(name)
      if !self.records.contains(resolved) {
        raise ScriptError("unknown storage type " + name)
      }
      Named(mangled(resolved))
    }
  }
}
