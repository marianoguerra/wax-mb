///|
test "AST-first proper tail call lowers to return_call" {
  let parsed = @parse.parse_module(
    "fn target(n :: i32) -> i32: n\nexport \"run\" fn run(n :: i32) -> i32: target(n)",
  )
  let module_ = parsed.module_()
  for j, decl in module_.decls {
    if decl is Fn(f) && f.name == "run" && f.body is Some(body) {
      if body[0].it is Call(target, args) {
        body[0] = { it: TailCall(target, args), span: body[0].span, }
        module_.decls[j] = Fn({ ..f, body: Some(body), })
      }
    }
  }
  let lowered = @lower.lower_module(module_)
  assert_true(lowered.diagnostics().is_empty())
  let session = @compile.Session::new()
  let checked = session.check(lowered.fields(), warn_unused=false)
  assert_false(@compile.rejected(session.reports()))
  assert_true(checked.to_wat().contains("return_call"))
}
