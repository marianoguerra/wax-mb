// Non-native targets.
//
// wax-mb is a command-line tool: it reads files, writes exact bytes to two
// separate streams, and sets an exit status. None of that exists on wasm-gc
// without host bindings this project does not define, and `moonbitlang/x/fs`
// -- which the CLI also needs -- is in the same position.
//
// So rather than silently degrade (routing stderr into stdout, or appending
// newlines `print` must not append), these fail loudly. The package still
// type-checks on every target, so `moon check --target all` stays meaningful.

///|
fn unsupported(what : String) -> Unit {
  abort("wax-mb: \{what} is only implemented for the native target")
}

///|
pub fn write_stdout_bytes(b : Bytes) -> Unit {
  ignore(b)
  unsupported("writing bytes to stdout")
}

///|
pub fn print(s : String) -> Unit {
  ignore(s)
  unsupported("writing to stdout")
}

///|
pub fn println(s : String) -> Unit {
  ignore(s)
  unsupported("writing to stdout")
}

///|
pub fn eprint(s : String) -> Unit {
  ignore(s)
  unsupported("writing to stderr")
}

///|
pub fn eprintln(s : String) -> Unit {
  ignore(s)
  unsupported("writing to stderr")
}

///|
/// No terminal to detect, so never colour.
pub fn stdout_is_tty() -> Bool {
  false
}

///|
pub fn stderr_is_tty() -> Bool {
  false
}
