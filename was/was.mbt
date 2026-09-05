// The was front end: shrubbery notation in, Wax AST or wasm out.

///|
/// Everything that can be wrong with a was program.
pub(all) struct Diagnostics {
  was : Array[@er.Report]
  wax : Array[@diagnostic.Diagnostic]
}

///|
/// True when nothing was found.
pub fn Diagnostics::is_empty(self : Self) -> Bool {
  self.was.length() == 0 && self.wax.length() == 0
}

///|
/// Read was source into the Wax AST.
///
/// A grouping error is fatal and comes back as a one-element list, because
/// there is no tree to read. Anything else is not: the module comes back with
/// whatever could be read, so one bad line does not hide the rest.
pub fn to_wax(
  src : String,
  fname? : String = "input.was",
) -> Result[@read.Read, Array[@er.Report]] {
  Ok(@read.read_module(src, fname~)) catch {
    @read.ReadError(r) => Err([r])
  }
}

///|
/// Compile was source to wasm.
pub fn compile_string(
  src : String,
  fname? : String = "input.was",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[Bytes, Diagnostics] raise @compile.CompileError {
  match check_string(src, fname~, features?, policy?) {
    Err(d) => Err(d)
    Ok(checked) => Ok(checked.to_bytes())
  }
}

///|
/// Compile was source to the WebAssembly text format.
pub fn compile_string_to_wat(
  src : String,
  fname? : String = "input.was",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[String, Diagnostics] raise @compile.CompileError {
  match check_string(src, fname~, features?, policy?) {
    Err(d) => Err(d)
    Ok(checked) => Ok(checked.to_wat())
  }
}

///|
/// Read and type check, stopping before the emitters.
pub fn check_string(
  src : String,
  fname? : String = "input.was",
  features? : @feature.Set,
  policy? : @warning.Policy,
) -> Result[@compile.Checked, Diagnostics] {
  let m = match to_wax(src, fname~) {
    Err(rs) => return Err({ was: rs, wax: [], })
    Ok(m) => m
  }
  if m.diagnostics().length() > 0 {
    return Err({ was: m.diagnostics(), wax: [], })
  }
  let session = @compile.Session::new(features?, source=src)
  let checked = session.check(m.fields())
  let reports = session.reports(policy?)
  if @compile.rejected(reports) {
    Err({ was: [], wax: reports, })
  } else {
    Ok(checked)
  }
}

///|
/// The Wax module fields a was file denotes.
///
/// This is the seam: the result is indistinguishable from what the Wax parser
/// produces for the equivalent .wax file, which is what makes was a notation
/// for Wax rather than a language above it.
pub fn fields(
  src : String,
  fname? : String = "input.was",
) -> Result[@ast.LocModule, Array[@er.Report]] {
  match to_wax(src, fname~) {
    Err(rs) => Err(rs)
    Ok(m) =>
      if m.diagnostics().length() > 0 {
        Err(m.diagnostics())
      } else {
        Ok(m.fields())
      }
  }
}

///|
/// Print a Wax module as was source.
///
/// This is the other half of the notation: `fields` says what a .was file
/// denotes, and this says that every Wax module can be written as one. The
/// tests close the loop -- read, print, read again, and compare the wasm --
/// which is what makes `wax -f was` and `wap -f was` something other than a
/// hope.
pub fn print_module(fields : @ast.LocModule) -> String {
  @print.module_(fields)
}

///|
/// Reformat was source: read it and print it back.
///
/// The type checker does not run, because a canonical layout is a front-end
/// question and a module that does not check still has one.
pub fn format_string(
  src : String,
  fname? : String = "input.was",
) -> Result[String, Array[@er.Report]] {
  match fields(src, fname~) {
    Err(rs) => Err(rs)
    Ok(f) => Ok(@print.module_(f))
  }
}
