// The distances are checked against the algorithm's published behaviour rather
// than against the reference binary: this is OCaml's own spellchecker, so the
// numbers are the ones every textbook gives for Damerau-Levenshtein.

///|
test "the textbook distances" {
  inspect(@spell.edit_distance("kitten", "sitting"), content="3")
  inspect(@spell.edit_distance("saturday", "sunday"), content="3")
  inspect(@spell.edit_distance("", "abc"), content="3")
  inspect(@spell.edit_distance("abc", "abc"), content="0")
}

///|
test "a transposition is one edit, not two" {
  // The Damerau in Damerau-Levenshtein, and the reason a typo like `lenght`
  // suggests `length` at all.
  inspect(@spell.edit_distance("ab", "ba"), content="1")
  inspect(@spell.edit_distance("lenght", "length"), content="1")
}

///|
test "the limit is an answer, not just a cutoff" {
  // Past the limit the true distance is never computed -- the caller only asked
  // whether anything is close.
  inspect(@spell.edit_distance("kitten", "sitting", limit=2), content="2")
  inspect(@spell.edit_distance("kitten", "sitting", limit=10), content="3")
  // A limit of 1 admits equality only.
  inspect(@spell.edit_distance("a", "b", limit=1), content="1")
  inspect(@spell.edit_distance("a", "a", limit=1), content="0")
}

///|
test "distance is over code points" {
  // One accented character is ONE edit away from its unaccented form, and a
  // character outside the basic plane is one character, not two.
  inspect(@spell.edit_distance("café", "cafe"), content="1")
  inspect(@spell.edit_distance("🦀", "🦞"), content="1")
  inspect(@spell.default_max_distance("🦀🦀🦀"), content="1")
}

///|
test "how far a suggestion may be depends on the word's length" {
  // A two-letter name is close to every other two-letter name, so nothing is
  // suggested for it.
  inspect(
    ["", "a", "ab", "abc", "abcd", "abcde"]
    .map(@spell.default_max_distance)
    .map(d => d.to_string())
    .join(" "),
    content="0 0 0 1 1 2",
  )
}

///|
test "suggest returns the closest names, ties included" {
  let dict = ["length", "lengths", "size", "count"]
  // Only `length`: it is one edit away, which tightens the limit and drops
  // `lengths` at two.
  inspect(@spell.suggest(dict.iter(), "lenght").join(" "), content="length")
  // A genuine tie keeps every equally-close name, in the dictionary's order:
  // `sile` is one edit from all three.
  inspect(
    @spell.suggest(["size", "site", "mile"].iter(), "sile").join(" "),
    content="size site mile",
  )
  // Nothing close enough at all.
  inspect(@spell.suggest(dict.iter(), "elephant").length(), content="0")
  // The order is the dictionary's: a tie is not the place to invent a
  // preference.
  inspect(@spell.suggest(["bb", "cc"].iter(), "ab").length(), content="0")
}

///|
test "a better candidate tightens the search" {
  // `size` is exact, so `sizes` -- one away -- is dropped rather than tied.
  inspect(
    @spell.suggest(["sizes", "size", "sized"].iter(), "size").join(" "),
    content="size",
  )
}
