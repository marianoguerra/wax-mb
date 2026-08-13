///|
/// The tree is READ from the spans, not re-derived, so the test that matters
/// is that a post-order run with its spans comes back as the nesting the
/// lowering meant.
test "a post-order run folds back to the tree it came from" {
  // `(i32.add (local.get 0) (i32.const 1))`, as the lowering emits it. Each
  // span is (start, where the node's OWN emission began, end):
  //   local.get 0   <- start 0, head 0, end 1
  //   i32.const 1   <- start 1, head 1, end 2
  //   i32.add       <- start 0, head 2, end 3, recorded last
  let body : Array[@wasm_bin.Instruction] = [LocalGet(0), I32Const(1), I32Add]
  let spans : Array[@wasm_bin.Span] = [
    { start: 0, head: 0, end: 1, loc: @basic.dummy_loc },
    { start: 1, head: 1, end: 2, loc: @basic.dummy_loc },
    { start: 0, head: 2, end: 3, loc: @basic.dummy_loc },
  ]
  let tree = fold(body, spans)
  inspect(tree.length(), content="1")
  inspect(tree[0].head is I32Add, content="true")
  inspect(tree[0].operands.length(), content="2")
  inspect(tree[0].operands[0].head is LocalGet(0), content="true")
  inspect(tree[0].operands[1].head is I32Const(1), content="true")
}

///|
/// A node that emitted nothing of its own is not a folded instruction: its
/// children are statements, and the last of them is not their head.
test "a node with no head of its own leaves its children alone" {
  let body : Array[@wasm_bin.Instruction] = [LocalGet(0), LocalGet(1)]
  // The tuple's own span ends where its head would have begun.
  let spans : Array[@wasm_bin.Span] = [
    { start: 0, head: 0, end: 1, loc: @basic.dummy_loc },
    { start: 1, head: 1, end: 2, loc: @basic.dummy_loc },
    { start: 0, head: 2, end: 2, loc: @basic.dummy_loc },
  ]
  let tree = fold(body, spans)
  inspect(tree.length(), content="2")
  inspect(tree[0].head is LocalGet(0), content="true")
  inspect(tree[1].head is LocalGet(1), content="true")
}

///|
test "two statements stay two" {
  let body : Array[@wasm_bin.Instruction] = [
    I32Const(1),
    Drop,
    I32Const(2),
    Drop,
  ]
  let spans : Array[@wasm_bin.Span] = [
    { start: 0, head: 0, end: 1, loc: @basic.dummy_loc },
    { start: 0, head: 1, end: 2, loc: @basic.dummy_loc },
    { start: 2, head: 2, end: 3, loc: @basic.dummy_loc },
    { start: 2, head: 3, end: 4, loc: @basic.dummy_loc },
  ]
  let tree = fold(body, spans)
  inspect(tree.length(), content="2")
  inspect(tree[0].head is Drop, content="true")
  inspect(tree[0].operands.length(), content="1")
  inspect(tree[1].operands[0].head is I32Const(2), content="true")
}
