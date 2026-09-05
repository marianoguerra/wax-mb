// The printer's test: read, print, read again, and require the same bytes.
//
// Round-tripping through the printer is a stronger check on the reader than
// on the printer: a form the printer emits differently from how it was written
// still has to mean the same thing, and byte equality is what says so.

///|
/// Read `src`, print the AST back as was, read that, and compare the wasm.
fn roundtrip(name : String, src : String) -> Unit raise {
  let first = match @was.compile_string(src, fname=name + ".was") {
    Ok(b) => b
    Err(d) => {
      for r in d.was {
        println(name + " READ: " + r.message)
      }
      fail(name + ": the source did not compile")
      return
    }
  }
  let printed = match @was.fields(src, fname=name + ".was") {
    Ok(f) => @print.module_(f)
    Err(_) => {
      fail(name + ": could not read")
      return
    }
  }
  let second = match @was.compile_string(printed, fname=name + ".printed.was") {
    Ok(b) => b
    Err(d) => {
      println("--- printed ---")
      println(printed)
      for r in d.was {
        println(name + " REREAD: " + r.message)
      }
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(printed), r)
      }
      println(sb.to_string())
      fail(name + ": the printed form did not compile")
      return
    }
  }
  if first != second {
    println("--- printed ---")
    println(printed)
    fail(name + ": printing changed the module")
  }
}

///|
test "round trip: the whole hashing module" {
  roundtrip("hashing", hashing_was)
}

///|
/// The `wax -f was` claim: take the Wax parser's own AST, print it as was,
/// read that back, and require the same wasm as compiling the .wax directly.
///
/// Nothing in this path is was's own parse tree -- the AST comes from Wax --
/// so it tests only whether the notation can say what Wax's front end
/// produced.
fn wax_to_was(name : String, wax_src : String) -> Unit raise {
  let expected = match @wax.compile_string(wax_src, fname=name + ".wax") {
    Ok(b) => b
    Err(_) => {
      fail(name + ": the .wax source did not compile")
      return
    }
  }
  let parsed = @wax.parse_string(wax_src, fname=name + ".wax")
  let fields = match parsed.module_ {
    Some(m) => m
    None => {
      fail(name + ": the .wax source did not parse")
      return
    }
  }
  let printed = @print.module_(fields)
  match @was.compile_string(printed, fname=name + ".was") {
    Ok(b) =>
      if b != expected {
        println("--- printed ---")
        println(printed)
        fail(name + ": printing to was changed the module")
      }
    Err(d) => {
      println("--- printed ---")
      println(printed)
      for r in d.was {
        println(name + " READ: " + r.message)
      }
      let sb = StringBuilder()
      let sink = @diagnostic.buffer_sink(sb)
      let theme = @diagnostic.get_theme(is_tty=false)
      for r in d.wax {
        @diagnostic.output_error(sink, theme, Human, Some(printed), r)
      }
      println(sb.to_string())
      fail(name + ": the printed was did not compile")
    }
  }
}

///|
test "wax -f was: the hashing module, printed from Wax's own AST" {
  wax_to_was("hashing", hashing_wax)
}
