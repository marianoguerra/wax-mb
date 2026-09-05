// The wap front end: source in, Wax AST or wasm out.

///|
/// Everything that can be wrong with a wap program.
///
/// wap's own reports and Wax's are kept apart because they are different types
/// with different renderers, not because a caller is expected to care which
/// stage found the problem.
pub(all) struct Diagnostics {
  wap : Array[@er.Report]
  wax : Array[@diagnostic.Diagnostic]
}

///|
/// True when nothing was found.
pub fn Diagnostics::is_empty(self : Self) -> Bool {
  self.wap.length() == 0 && self.wax.length() == 0
}

///|
/// A parsed and lowered module, before Wax has checked it.
pub struct Module {
  fields : @ast.LocModule
  sources : @er.Sources
  diagnostics : Array[@er.Report]
}

///|
/// The Wax module fields.
///
/// This is the seam an embedder uses: build these from wap source, add fields
/// built with `marianoguerra/wax/ast/build`, and compile the lot. No stage of
/// that produces or consumes source text.
pub fn Module::fields(self : Self) -> @ast.LocModule {
  self.fields
}

///|
/// The source registry the reports point into.
pub fn Module::sources(self : Self) -> @er.Sources {
  self.sources
}

///|
/// Problems found while parsing and lowering.
pub fn Module::diagnostics(self : Self) -> Array[@er.Report] {
  self.diagnostics
}

///|
/// Parse and lower wap source to the Wax AST.
///
/// A parse error is fatal and comes back as a one-element error list, because
/// there is no tree to lower. A lowering error is not: the module comes back
/// with whatever could be lowered, so one bad line does not hide the rest.
pub fn to_wax(
  src : String,
  fname? : String = "input.wap",
) -> Result[Module, Array[@er.Report]] {
  let parsed = @parse.parse_module(src, fname~) catch {
    @parse.ParseError(r) => return Err([r])
  }
  let lowered = @lower.lower_module(
    parsed.module_(),
    text=src,
    fname~,
    src=parsed.source(),
  )
  Ok({
    fields: lowered.fields(),
    sources: parsed.sources(),
    diagnostics: lowered.diagnostics(),
  })
}

///|
/// Compile wap source to wasm.
pub fn compile_string(
  src : String,
  fname? : String = "input.wap",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[Bytes, Diagnostics] raise @compile.CompileError {
  match check_string(src, fname~, features?, policy?) {
    Err(d) => Err(d)
    Ok((checked, _)) => Ok(checked.to_bytes())
  }
}

///|
/// Compile wap source to the WebAssembly text format.
pub fn compile_string_to_wat(
  src : String,
  fname? : String = "input.wap",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[String, Diagnostics] raise @compile.CompileError {
  match check_string(src, fname~, features?, policy?) {
    Err(d) => Err(d)
    Ok((checked, _)) => Ok(checked.to_wat())
  }
}

///|
/// Parse, lower and type check, stopping before the emitters.
pub fn check_string(
  src : String,
  fname? : String = "input.wap",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[(@compile.Checked, Module), Diagnostics] {
  let m = match to_wax(src, fname~) {
    Err(rs) => return Err({ wap: rs, wax: [], })
    Ok(m) => m
  }
  if m.diagnostics.length() > 0 {
    return Err({ wap: m.diagnostics, wax: [], })
  }
  let session = @compile.Session::new(features?, source=src)
  let checked = session.check(m.fields)
  let reports = session.reports(policy?)
  if @compile.rejected(reports) {
    Err({ wap: [], wax: reports, })
  } else {
    Ok((checked, m))
  }
}
