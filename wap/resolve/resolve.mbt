// Resolving `import a.b` to the modules a program is made of.

///|
/// Where a module's source comes from.
///
/// `path` is the dotted path as written -- `import collections.hashing` asks
/// for `"collections.hashing"` -- and `None` means the loader does not have
/// it. What that path denotes is entirely the loader's business: a directory
/// layout, a zip entry, a database row, a literal map.
pub(open) trait Loader {
  fn load(Self, String) -> String?
}

///|
/// A loader over sources already in memory.
///
/// This is the one a test, a playground or a code generator wants, and it is
/// also the proof that the resolver does not need a filesystem: nothing else
/// in this package would change if it did.
pub struct MapLoader {
  sources : Map[String, String]
}

///|
/// A loader over the given `(path, source)` pairs.
pub fn MapLoader::new(entries? : Array[(String, String)] = []) -> MapLoader {
  let sources : Map[String, String] = Map([])
  for e in entries {
    let (k, v) = e
    sources[k] = v
  }
  { sources, }
}

///|
/// Add or replace one module's source.
pub fn MapLoader::add(self : MapLoader, path : String, src : String) -> Unit {
  self.sources[path] = src
}

///|
pub impl Loader for MapLoader with fn load(self, path) {
  self.sources.get(path)
}

///|
/// A resolution failure, as a ready-to-render report.
pub(all) suberror ResolveError {
  ResolveError(@er.Report)
}

///|
/// The report inside the error.
pub fn ResolveError::report(self : Self) -> @er.Report {
  let ResolveError(r) = self
  r
}

///|
/// A whole program: every module it needs, in dependency order.
pub struct Program {
  units : Array[@lower.Input]
  sources : @er.Sources
}

///|
/// The modules, dependencies first, ready for `@lower.lower_program`.
pub fn Program::units(self : Self) -> Array[@lower.Input] {
  self.units
}

///|
/// The source registry every diagnostic points into.
pub fn Program::sources(self : Self) -> @er.Sources {
  self.sources
}

///|
/// The entry module's name.
pub fn Program::entry(self : Self) -> String {
  if self.units.length() == 0 {
    ""
  } else {
    self.units[self.units.length() - 1].module_.name
  }
}

///|
/// Resolve a program from source already in hand.
///
/// The entry module is not asked of the loader -- a caller compiling a buffer
/// has it already -- and everything it imports is.
pub fn resolve_source(
  path : String,
  src : String,
  loader : &Loader,
) -> Program raise ResolveError {
  let sources = @er.Sources::new()
  let units = []
  let done : Map[String, Unit] = Map([])
  let visiting : Map[String, Unit] = Map([])
  walk(path, Some(src), loader, sources, units, done, visiting, [])
  { units, sources, }
}

///|
/// Resolve a program by asking the loader for the entry module too.
pub fn resolve(path : String, loader : &Loader) -> Program raise ResolveError {
  let sources = @er.Sources::new()
  let units = []
  let done : Map[String, Unit] = Map([])
  let visiting : Map[String, Unit] = Map([])
  walk(path, None, loader, sources, units, done, visiting, [])
  { units, sources, }
}

///|
/// Depth first, pushing each module after everything it imports.
///
/// `stack` is only for the error message: a cycle is worth naming in full,
/// because which edge to cut is the programmer's decision and they need to see
/// the ring to make it.
fn walk(
  path : String,
  provided : String?,
  loader : &Loader,
  sources : @er.Sources,
  units : Array[@lower.Input],
  done : Map[String, Unit],
  visiting : Map[String, Unit],
  stack : Array[String],
) -> Unit raise ResolveError {
  if done.contains(path) {
    return
  }
  if visiting.contains(path) {
    let ring = (stack + [path]).join(" -> ")
    raise ResolveError(
      @er.Report::error("these modules import each other: " + ring).with_help(
        "wap has no forward declarations across modules; break the cycle by moving the shared declarations into a third module",
      ),
    )
  }
  let text = match provided {
    Some(t) => t
    None =>
      match loader.load(path) {
        Some(t) => t
        None =>
          raise ResolveError(
            @er.Report::error("cannot find module `" + path + "`").with_help(
              "the loader has no source for that path",
            ),
          )
      }
  }
  let fname = path + ".wap"
  let src = sources.add(fname, text)
  let parsed = @parse.parse_module(text, fname~) catch {
    @parse.ParseError(r) => raise ResolveError(r)
  }
  let m = parsed.module_()
  visiting[path] = ()
  stack.push(path)
  for d in m.decls {
    match d {
      Import(p) =>
        walk(p.join("."), None, loader, sources, units, done, visiting, stack)
      _ => ()
    }
  }
  let _ = stack.pop()
  visiting.remove(path)
  done[path] = ()
  units.push({ module_: m, source: { fname, text, src, }, })
}
