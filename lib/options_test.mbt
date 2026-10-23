// The compile options that change the bytes without changing the module.

///|
test "label names can be left out of the name section" {
  let src =
    #|#[export]
    #|fn f(x: i32) -> i32 { 'done: do { if x { br 'done 1; } 2; } }
    #|
  let with_labels = match @wax.compile_string(src) {
    Ok(b) => b
    Err(_) => abort("expected it to compile")
  }
  let without = match @wax.compile_string(src, label_names=false) {
    Ok(b) => b
    Err(_) => abort("expected it to compile")
  }
  // The label's name, `done`, is in the name section only when asked for.
  fn has_done(b : Bytes) -> Bool {
    for i in 0..<(b.length() - 3) {
      if b[i] == b'd' &&
        b[i + 1] == b'o' &&
        b[i + 2] == b'n' &&
        b[i + 3] == b'e' {
        return true
      }
    }
    false
  }

  assert_true(has_done(with_labels))
  assert_false(has_done(without))
  assert_true(without.length() < with_labels.length())
}
