// "Did you mean …?" -- the distance behind a suggestion.
//
// Ported from wax/src/lib-utils/spell_check.ml, which is OCaml's own
// `Misc.spellcheck` (INRIA, LGPL 2.1 with the linking exception): a
// Damerau-Levenshtein distance computed on a BAND around the diagonal, so a
// word that is obviously too far away is abandoned rather than measured.
//
// The band is what makes it usable on a whole namespace: `suggest` walks every
// name in scope, and the limit tightens as better candidates are found, so most
// names cost O(limit) rather than O(n*m).
//
// Distances are over CODE POINTS, not UTF-16 units: `é` is one edit away from
// `e`, not two, and a name outside the basic plane is one character.

///|
/// The Damerau-Levenshtein distance between two strings, capped at `limit`.
///
/// Returns `limit` when the true distance is greater -- the caller only ever
/// wants to know whether something is close, so there is no reason to finish
/// measuring how far.
pub fn edit_distance(
  a : String,
  b : String,
  limit? : Int = @int.MAX_VALUE,
) -> Int {
  distance_from(a, code_points(a), b, limit~)
}

///|
/// The code points of a string, so a multi-unit character counts once.
fn code_points(s : String) -> Array[Char] {
  let out = []
  for c in s {
    out.push(c)
  }
  out
}

///|
/// `edit_distance` with the first string already decoded.
///
/// `suggest` decodes the query once and measures it against every candidate,
/// which is the whole reason this split exists.
fn distance_from(
  a : String,
  a_points : Array[Char],
  b : String,
  limit? : Int = @int.MAX_VALUE,
) -> Int {
  // A limit of 1 admits only equality, and equality is cheaper to test than to
  // measure.
  if limit <= 1 {
    return if a == b { 0 } else { limit }
  }
  let b_points = code_points(b)
  let mut len_a = a_points.length()
  let mut len_b = b_points.length()
  let limit = @cmp.minimum(@cmp.maximum(len_a, len_b), limit)
  // Lengths that differ by more than the limit cannot be within it: every
  // missing character costs at least one edit.
  if (len_b - len_a).abs() >= limit {
    return limit
  }
  // Work with the longer string as the outer loop, so the rows are the shorter
  // one and the band is as narrow as it can be.
  let mut s0 = a_points
  let mut s1 = b_points
  if len_a <= len_b {
    s0 = b_points
    s1 = a_points
    let t = len_a
    len_a = len_b
    len_b = t
  }
  // Three rows: the previous two (Damerau's transposition needs i-2) and the
  // one being filled. Cells outside the band are left at `ignore`, which is
  // above the limit, so they never win a minimum.
  let ignore = limit + 1
  let mut row_minus2 = Array::make(len_b + 1, ignore)
  let mut row_minus1 = Array::makei(len_b + 1, x => x)
  let mut row = Array::make(len_b + 1, ignore)
  for i = 1; i <= len_a; i = i + 1 {
    let mut row_min = @int.MAX_VALUE
    row[0] = i
    let jmax = {
      let j = @cmp.minimum(len_b, i + limit - 1)
      // `i + limit` can overflow when no limit was given.
      if j < 0 {
        len_b
      } else {
        j
      }
    }
    for j = @cmp.maximum(1, i - limit); j <= jmax; j = j + 1 {
      let cost = if s0[i - 1] == s1[j - 1] { 0 } else { 1 }
      let mut best = @cmp.minimum(
        row_minus1[j - 1] + cost, // substitute
        @cmp.minimum(row_minus1[j] + 1, row[j - 1] + 1), // delete, insert
      )
      // Transpose: the Damerau in Damerau-Levenshtein, which is what makes
      // `lenght` one edit from `length` rather than two.
      if i > 1 && j > 1 && s0[i - 1] == s1[j - 2] && s0[i - 2] == s1[j - 1] {
        best = @cmp.minimum(best, row_minus2[j - 2] + cost)
      }
      row[j] = best
      row_min = @cmp.minimum(row_min, best)
    }
    // Every cell in this row is already at the limit, and a row never
    // decreases below its predecessor's minimum.
    if row_min >= limit {
      return limit
    }
    let spare = row_minus2
    row_minus2 = row_minus1
    row_minus1 = row
    row = spare
  }
  let d = row_minus1[row_minus1.length() - 1]
  if d > limit {
    limit
  } else {
    d
  }
}

///|
/// How far a suggestion may be from a word of this length.
///
/// Nothing for one or two characters (every short name is close to every
/// other), one edit up to four, two beyond. OCaml's numbers.
pub fn default_max_distance(s : String) -> Int {
  match code_points(s).length() {
    0 | 1 | 2 => 0
    3 | 4 => 1
    _ => 2
  }
}

///|
/// The names in `dictionary` closest to `word`, if any are close enough.
///
/// All the equally-closest ones, in the order the dictionary yielded them: a
/// tie is not the place to invent a preference. The limit tightens as better
/// candidates are found, so a long namespace costs little.
pub fn suggest(
  dictionary : Iter[String],
  word : String,
  max_distance? : (String) -> Int = default_max_distance,
) -> Array[String] {
  let mut best = max_distance(word)
  let out = []
  let points = code_points(word)
  for candidate in dictionary {
    let d = distance_from(word, points, candidate, limit=best + 1)
    if d == best {
      out.push(candidate)
    } else if d < best {
      best = d
      out.clear()
      out.push(candidate)
    }
  }
  out
}
