// Reading the source text back, for the suggestion quick fixes.
//
// A machine-applicable suggestion has to splice a rewrite into the exact bytes
// a construct occupies -- the ` as t` suffix of a redundant cast, the `: x` of
// a punned field -- so the checker reaches back into the source for them.

///|
/// The source text a span covers, or `None` when the source is unavailable or
/// the span does not fit it.
pub fn source_slice(source : String?, loc : @basic.Location) -> String? {
  guard source is Some(src) else { return None }
  let s = loc.start.cnum
  let e = loc.end.cnum
  if 0 <= s && s <= e && e <= src.length() {
    Some(src[s:e].to_owned())
  } else {
    None
  }
}

///|
/// The source with every comment blanked to spaces, newlines kept.
///
/// The source-scanning suggestions look for a delimiter -- a `:`, a `|`, a
/// keyword -- to decide where a rewrite goes, and one inside a comment is not
/// syntax. Blanking rather than deleting is what keeps every byte offset and
/// the line structure intact, so a span found in the blanked text addresses the
/// same bytes in the real one.
///
/// Wax has `//` line comments and `/* */` block comments, and the block
/// comments NEST -- so this counts depth rather than scanning for the first
/// close.
pub fn blank_comments(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  let out = Array::makei(n, i => cs[i])
  fn blank(lo : Int, hi : Int) -> Unit {
    for k in lo..<hi {
      if cs[k] != '\n' {
        out[k] = ' '
      }
    }
  }

  let mut i = 0
  while i < n {
    if i + 1 < n && cs[i] == '/' && cs[i + 1] == '/' {
      let mut j = i + 2
      while j < n && cs[j] != '\n' {
        j += 1
      }
      blank(i, j)
      i = j
    } else if i + 1 < n && cs[i] == '/' && cs[i + 1] == '*' {
      let mut j = i + 2
      let mut depth = 1
      while depth > 0 && j < n {
        if j + 1 < n && cs[j] == '/' && cs[j + 1] == '*' {
          j += 2
          depth += 1
        } else if j + 1 < n && cs[j] == '*' && cs[j + 1] == '/' {
          j += 2
          depth -= 1
        } else {
          j += 1
        }
      }
      blank(i, j)
      i = j
    } else {
      i += 1
    }
  }
  String::from_array(out)
}
