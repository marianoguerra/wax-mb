// Rendering a diagnostic against its source text.

///|
fn repeat_str(s : String, n : Int) -> String {
  if n <= 0 {
    return ""
  }
  let out = StringBuilder()
  for _ in 0..<n {
    out.write_string(s)
  }
  out.to_string()
}

///|
/// Left-pad `s` to `width`.
fn pad_left(s : String, width : Int) -> String {
  repeat_str(" ", width - s.length()) + s
}

///|
/// Render `d` with a source snippet.
fn output_with_source(
  sink : Sink,
  theme : Theme,
  source : String,
  d : Diagnostic,
) -> Unit {
  let annotations = get_annotations(theme, d)
  let hunks = get_hunks(annotations)
  let line_starts = get_line_starts(source)
  let total_lines = line_starts.length()
  let mut max_hunk_line = 0
  for h in hunks {
    max_hunk_line = @cmp.maximum(max_hunk_line, h.1)
  }
  // The gutter is sized for the widest line number ACTUALLY printed, not for
  // the file's last line: a diagnostic near the top of a 10000-line file gets a
  // narrow gutter.
  let max_line = @cmp.minimum(max_hunk_line, total_lines)
  let gutter_width = @cmp.maximum(1, max_line.to_string().length())
  let gutter_padding = repeat_str(" ", gutter_width)
  let start = d.loc.start
  output_no_loc(sink, theme, d.severity, d.warning, None, d.message)
  // The location line. Its column is 1-BASED, unlike the JSON format's.
  line(
    sink,
    with_style(theme.line_numbers, gutter_padding + "──➤") +
    "  \{start.fname}:\{start.lnum}:\{start.column1()}",
  )
  fn print_line(
    header : String,
    gutter_char : String,
    contents : String,
  ) -> Unit {
    line(
      sink,
      with_style(theme.line_numbers, header + " " + gutter_char) +
      " " +
      contents,
    )
  }

  let mut curr_pos = 0
  let mut curr_line = 1
  let total_hunks = hunks.length()
  for i, hunk in hunks {
    if i > 0 {
      // A gap between hunks, marked rather than silently skipped.
      line(
        sink,
        with_style(theme.line_numbers, gutter_padding + " ·") + " ...",
      )
    }
    let (s_line, e_line) = hunk
    if s_line <= total_lines {
      curr_pos = line_starts[s_line - 1]
      curr_line = s_line
    } else {
      curr_pos = source.length()
      curr_line = total_lines + 1
    }
    let last_line_of_hunk = @cmp.minimum(e_line, total_lines)
    while curr_line <= last_line_of_hunk {
      let is_last_line = curr_line == last_line_of_hunk && i == total_hunks - 1
      let (raw_content, next_eol) = line_info(source, curr_pos)
      print_line(
        pad_left(curr_line.to_string(), gutter_width),
        "│",
        @unicode.expand_tabs(raw_content),
      )
      let on_this_line = annotations.filter(a => {
        curr_line >= a.start_line && curr_line <= a.end_line
      })
      let num_annots = on_this_line.length()
      // A column measured in DISPLAY columns, not bytes: a wide glyph or a tab
      // ahead of the span shifts the caret.
      fn vis_col(col : Int) -> Int {
        let col = @cmp.minimum(raw_content.length(), col)
        @unicode.terminal_width(raw_content.view(end_offset=col).to_owned())
      }

      for j, a in on_this_line {
        let is_last_annot = is_last_line && j == num_annots - 1
        let gutter_char = if is_last_annot { " " } else { "·" }
        let is_start = curr_line == a.start_line
        let is_end = curr_line == a.end_line
        // A single-line span is underlined with a run of carets. A span
        // crossing several lines is drawn as a SPINE: the start line marks the
        // construct's first column with a corner and a reach out to it, each
        // middle line carries a vertical connector, and the last line closes
        // with a corner reaching the final column, then the label.
        let carets = if is_start && is_end {
          let start_vis = vis_col(a.start_col)
          let end_vis = vis_col(a.end_col)
          repeat_str(" ", start_vis) +
          repeat_str("^", @cmp.maximum(1, end_vis - start_vis))
        } else {
          // One box-drawing glyph is one display column, so a reach of
          // `caret - 1` dashes lands the caret at column `caret`. A construct
          // flush to column 0 has the corner itself sit on it, so no reach.
          fn reach(caret : Int) -> String {
            if caret <= 0 {
              ""
            } else {
              repeat_str("─", caret - 1) + "^"
            }
          }

          if is_start {
            "╭" + reach(vis_col(a.start_col))
          } else if is_end {
            "╰" + reach(@cmp.maximum(1, vis_col(a.end_col)) - 1)
          } else {
            "│"
          }
        }
        // Labels are short, and rendered FLAT so they sit on the caret's line
        // in the caret's colour rather than nested inside body ANSI.
        let label = match a.label {
          Some(m) if is_end =>
            " " + with_style(a.color, @message.to_plain_string(m))
          _ => ""
        }
        print_line(
          gutter_padding,
          gutter_char,
          with_style(a.color, carets) + label,
        )
      }
      curr_pos = @cmp.minimum(source.length(), next_eol + 1)
      curr_line = curr_line + 1
    }
  }
  print_hint(sink, theme, d.hint)
  print_fix(sink, theme, d.severity, d.warning, d.edit)
}

///|
/// Render one diagnostic in whichever format is selected.
pub fn output_error(
  sink : Sink,
  theme : Theme,
  format : OutputFormat,
  source : String?,
  d : Diagnostic,
) -> Unit {
  match format {
    Json => output_json(sink, d)
    Short => output_short(sink, d)
    Human =>
      // With no span at all there is nothing to point at; with a span but no
      // source text, the location is stated in prose instead.
      if d.loc.start.is_dummy() {
        output_no_loc(sink, theme, d.severity, d.warning, d.hint, d.message)
      } else {
        match source {
          None => output_no_source(sink, theme, d)
          Some(src) => output_with_source(sink, theme, src, d)
        }
      }
  }
}
