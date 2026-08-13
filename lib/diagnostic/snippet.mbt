// The source snippet: line gutter, carets, and the multi-line span spine.

///|
/// One span to be drawn under the source.
priv struct Annotation {
  start_line : Int
  end_line : Int
  start_col : Int
  end_col : Int
  color : String
  /// A note printed after the caret, on the span's last line.
  label : @message.Message?
}

///|
/// The main span, then one per related label.
fn get_annotations(theme : Theme, d : Diagnostic) -> Array[Annotation] {
  let color = match d.severity {
    Error => theme.error_label
    Warning => theme.warning_label
    Suggestion => theme.secondary_label
  }
  let out = [
    {
      start_line: d.loc.start.lnum,
      end_line: d.loc.end.lnum,
      start_col: d.loc.start.column0(),
      end_col: d.loc.end.column0(),
      color,
      label: None,
    },
  ]
  for l in d.related {
    out.push({
      start_line: l.loc.start.lnum,
      end_line: l.loc.end.lnum,
      start_col: l.loc.start.column0(),
      end_col: l.loc.end.column0(),
      color: theme.secondary_label,
      label: Some(l.message),
    })
  }
  out
}

///|
/// How many lines of context surround an annotated line.
const CONTEXT : Int = 2

///|
/// The line ranges to print: every annotation's endpoints plus context,
/// merged where they touch or overlap.
///
/// Ranges only ADJACENT (`s2 <= e1 + 1`) are merged too, so two hunks a single
/// line apart become one rather than being separated by a `...` marker that
/// hides nothing.
fn get_hunks(annotations : Array[Annotation]) -> Array[(Int, Int)] {
  let ranges = []
  for a in annotations {
    ranges.push((a.start_line - CONTEXT, a.start_line + CONTEXT))
    ranges.push((a.end_line - CONTEXT, a.end_line + CONTEXT))
  }
  // A STABLE sort on the start line: equal starts keep annotation order, so
  // the merge below is deterministic.
  let sorted = ranges.copy()
  sorted.sort_by((x, y) => x.0.compare(y.0))
  let merged : Array[(Int, Int)] = []
  for r in sorted {
    match merged.last() {
      Some(prev) if r.0 <= prev.1 + 1 =>
        merged[merged.length() - 1] = (
          @cmp.minimum(prev.0, r.0),
          @cmp.maximum(prev.1, r.1),
        )
      _ => merged.push(r)
    }
  }
  merged.map(r => (@cmp.maximum(1, r.0), r.1))
}

///|
/// The byte offset at which each line starts.
fn get_line_starts(source : String) -> Array[Int] {
  let starts = [0]
  let mut i = 0
  let n = source.length()
  while i < n {
    if source.unsafe_get(i).to_int() == 0x0A {
      starts.push(i + 1)
    }
    i = i + 1
  }
  starts
}

///|
/// The text of the line starting at `bol`, and the offset of its newline.
fn line_info(source : String, bol : Int) -> (String, Int) {
  if bol >= source.length() {
    return ("", bol)
  }
  let mut e = bol
  while e < source.length() && source.unsafe_get(e).to_int() != 0x0A {
    e = e + 1
  }
  (source.view(start_offset=bol, end_offset=e).to_owned(), e)
}
