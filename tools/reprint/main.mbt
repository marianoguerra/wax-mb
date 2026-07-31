///|
/// Reprint one file, as `wax <file> -f wax` does.
///
/// The porting inner loop: tools/reprint_diff.sh runs this and the reference
/// over the same input and diffs them.
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("usage: reprint <file.wax>")
    return
  }
  let path = args[1]
  let src = @fs.read_file_to_string(path) catch {
    e => {
      println("cannot read \{path}")
      ignore(e)
      return
    }
  }
  let r = @grammar.parse_string(src, fname=path)
  match r.module_ {
    // render drops the trailing break; println supplies the final newline the
    // reference emits.
    Some(m) => println(@output.render(m, r.trivia))
    None => println("parse error: " + r.errors[0].message)
  }
}
