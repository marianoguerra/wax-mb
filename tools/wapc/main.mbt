// Compile the wap sources in a directory tree.
//
// This exists to give `stdlib-wap/` a build: a module there imports another by
// its dotted path, so nothing about it can be checked one file at a time, and
// the resolver needs a `Loader` that reads files. That implementation is the
// only piece the wap README describes without shipping, and it belongs here
// rather than in `wap/` -- reading a file costs `moonbitlang/x`, which a
// library that compiles source text should not make every consumer pay for.

///|
/// A `Loader` over a directory: `collections.hashing` is
/// `<root>/collections/hashing.wap`.
///
/// It remembers what it read, because a Wax diagnostic names the file it is
/// about and the renderer wants that file's text to draw a snippet. Without
/// the cache a type error three modules deep would be shown against the entry
/// module's source, quoting the wrong line with perfect confidence.
struct Files {
  root : String
  read : Map[String, String]
}

///|
fn Files::new(root : String) -> Files {
  { root, read: {}, }
}

///|
/// The file a module path is looked for at.
fn Files::path_of(self : Files, path : String) -> String {
  self.root + "/" + path.replace_all(old=".", new="/") + ".wap"
}

///|
impl @resolve.Loader for Files with fn load(self, path) {
  let file = self.path_of(path)
  let text = @fs.read_file_to_string(file) catch { _ => return None }
  // Keyed the way the resolver names its sources -- `path + ".wap"` -- so that
  // a diagnostic can be traced back to the text it is about.
  self.read[path + ".wap"] = text
  Some(text)
}

///|
/// Every `.wap` file under a directory, as dotted module paths, sorted.
fn discover(root : String) -> Array[String] {
  let out = []
  walk(root, "", out)
  out.sort()
  out
}

///|
fn walk(root : String, prefix : String, out : Array[String]) -> Unit {
  let dir = if prefix == "" { root } else { root + "/" + prefix }
  let entries = @fs.read_dir(dir) catch { _ => return }
  for entry in entries {
    let rel = if prefix == "" { entry } else { prefix + "/" + entry }
    let nested = @fs.is_dir(root + "/" + rel) catch { _ => false }
    if nested {
      walk(root, rel, out)
    } else if rel.has_suffix(".wap") {
      let stem = rel[:rel.length() - 4].to_owned()
      out.push(stem.replace_all(old="/", new="."))
    }
  }
}

///|
/// Render wap's own reports.
///
/// The signature is spelled out because it is also what makes the
/// `error-report` import a use: MoonBit does not count reaching into a struct
/// as one, and these reports are read field by field.
fn render_reports(reports : Array[@er.Report], sources : @er.Sources) -> String {
  let sb = StringBuilder()
  for r in reports {
    sb.write_string(
      @render.render_string(r, sources, @render.default_config, is_tty=false),
    )
  }
  sb.to_string()
}

///|
/// The text a Wax diagnostic is about.
///
/// A diagnostic names its file, and in a program of several modules that is
/// not the entry module. Looking it up is what stops a type error three
/// modules deep from being drawn against the wrong source, quoting an
/// unrelated line with perfect confidence.
fn source_for(files : Files, loc : @basic.Location) -> String? {
  files.read.get(loc.start.fname)
}

///|
/// Compile one module and everything it imports.
///
/// Returns the wat, or the rendered diagnostics. Nothing here decides what to
/// print: the caller does, because a sweep over a tree wants one line per
/// module and a single `--wat` run wants the whole output.
///
/// It walks the two halves itself rather than calling `compile_program_to_wat`
/// so that the resolver's `Sources` is in hand when a wap report needs
/// rendering -- the facade drops it on the error path, having nothing to say
/// about how a caller displays things.
fn compile_one(
  files : Files,
  path : String,
) -> Result[String, String] raise @compile.CompileError {
  let src = match @resolve.Loader::load(files, path) {
    Some(s) => s
    None => return Err("cannot read " + files.path_of(path) + "\n")
  }
  let m = match @wap.program_to_wax(path, src, files) {
    // A resolve or parse failure comes back with no registry to point into,
    // so the report is rendered against an empty one: the message and the
    // code, without a snippet.
    Err(rs) => return Err(render_reports(rs, @er.Sources::new()))
    Ok(m) => m
  }
  if m.diagnostics().length() > 0 {
    return Err(render_reports(m.diagnostics(), m.sources()))
  }
  let session = @compile.Session::new(source=src)
  let checked = session.check(m.fields())
  let reports = session.reports()
  if !@compile.rejected(reports) {
    return Ok(checked.to_wat())
  }
  let sb = StringBuilder()
  let sink = @diagnostic.buffer_sink(sb)
  let theme = @diagnostic.get_theme(is_tty=false)
  for r in reports {
    @diagnostic.output_error(sink, theme, Human, source_for(files, r.loc), r)
  }
  Err(sb.to_string())
}

///|
fn main raise {
  let args = @env.args()
  let mut root = "stdlib-wap"
  let mut wat = false
  let wanted = []
  let mut i = 1
  while i < args.length() {
    match args[i] {
      "--root" => {
        i = i + 1
        root = args[i]
      }
      "--wat" => wat = true
      "--help" | "-h" => {
        usage()
        return
      }
      other => wanted.push(other)
    }
    i = i + 1
  }
  let modules = if wanted.length() > 0 { wanted } else { discover(root) }
  if modules.length() == 0 {
    println("wapc: no .wap sources under " + root)
    @sys.exit(2)
  }
  let mut failed = 0
  for path in modules {
    let files = Files::new(root)
    match compile_one(files, path) {
      Ok(w) => if wat { println(w) } else { println("ok    " + path) }
      Err(message) => {
        println("FAIL  " + path)
        println(message)
        failed = failed + 1
      }
    }
  }
  if failed != 0 {
    println("wapc: \{failed} of \{modules.length()} modules failed")
    @sys.exit(1)
  }
  if !wat {
    println("wapc: \{modules.length()} modules compiled")
  }
}

///|
fn usage() -> Unit {
  println("usage: wapc [--root DIR] [--wat] [MODULE...]")
  println("")
  println("  Compiles each MODULE, and everything it imports, through wap.")
  println("  With no MODULE, every .wap file under DIR (default stdlib-wap).")
  println("  MODULE is a dotted path: collections.hashing")
}
