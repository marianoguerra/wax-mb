// Writing exact bytes to stdout and stderr.

///|
/// `#borrow`: the C side only reads the buffer during the call and never
/// retains it, so ownership stays with MoonBit.
#borrow(s)
extern "C" fn write_stdout(s : Bytes, len : Int) = "wax_write_stdout"

///|
#borrow(s)
extern "C" fn write_stderr(s : Bytes, len : Int) = "wax_write_stderr"

///|
/// Write `s` to stdout as UTF-8, adding NOTHING.
///
/// Unlike `println`, which would append a newline the reference does not emit.
pub fn print(s : String) -> Unit {
  let b = @utf8.encode(s)
  write_stdout(b, b.length())
}

///|
pub fn println(s : String) -> Unit {
  print(s + "\n")
}

///|
/// Write `s` to stderr as UTF-8, adding nothing.
pub fn eprint(s : String) -> Unit {
  let b = @utf8.encode(s)
  write_stderr(b, b.length())
}

///|
pub fn eprintln(s : String) -> Unit {
  eprint(s + "\n")
}

///|
extern "C" fn isatty_fd(which : Int) -> Int = "wax_isatty_fd"

///|
/// Whether stdout is a terminal.
pub fn stdout_is_tty() -> Bool {
  isatty_fd(1) == 1
}

///|
/// Whether stderr is a terminal.
pub fn stderr_is_tty() -> Bool {
  isatty_fd(2) == 1
}
