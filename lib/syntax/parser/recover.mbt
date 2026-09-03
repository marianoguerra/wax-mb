// Panic-mode error recovery: report every syntax error, not just the first.
//
// MoonYacc has none ("MoonYacc does not support error recovery at the moment",
// doc/MANUAL.md), and its generated `parse` is all-or-nothing: it raises at the
// first unexpected token and the parse is over. `wax check --all-errors` needs
// the opposite, so this drives the SAME tables (`yy_state`, `yy_input`, the
// action table) in a loop that can repair the stream and carry on.
//
// Two repairs, in the order the reference tries them (`recover.ml` +
// `Parsing.Make.parse_recover`):
//
//   * INSERT a token the erroring state could shift. The only candidate is `;`,
//     because a dropped statement separator is the common slip and the state
//     after a complete statement can shift one -- so the report is a precise
//     "Missing ';'." rather than a skip to the next boundary.
//   * SKIP to a resynchronization point, then unwind the stack to a state that
//     can shift it. The scan is nesting-aware: a closer or `;` belonging to a
//     group opened inside the skipped span does not resync the enclosing
//     construct.
//
// The actions run, so the tree is the real one, best-effort. That matters less
// here than it does upstream (there is no type checker yet to hand it to) but
// it keeps the data stack in step with the state stack, which is what makes
// unwinding sound: states and values are popped together, so a later reduction
// still finds values of the types its production's symbols imply.

///|
/// How a token behaves when recovery is looking for somewhere to resume.
///
/// Ported from the reference's `recover.ml`. The classification is the
/// grammar's, not the automaton's, which is why it is a plain function on
/// tokens rather than anything table-driven.
priv enum Sync {
  /// `{` `(` `[` -- descend a nesting level while skipping.
  Open
  /// `}` `)` `]` -- resync, but only at the outer level.
  Close
  /// `;` -- resync, but only at the outer level.
  Boundary
  /// A keyword that can only START a top-level item or a statement, so it
  /// resyncs at ANY depth: an unbalanced opener must not swallow the next item.
  /// The expression-shaped keywords (`if`, `loop`, `do`, `while`, `match`) are
  /// deliberately absent -- in this expression-oriented grammar they occur
  /// mid-expression, and stopping at one would resync too early.
  Leader
  /// End of input: recovery stops.
  Terminal
  /// Everything else: skipped.
  Skip
}

///|
fn sync_class(t : Token) -> Sync {
  match t {
    LBRACE | LPAREN | LBRACKET => Open
    RBRACE | RPAREN | RBRACKET => Close
    SEMI => Boundary
    FN
    | TYPE
    | REC
    | IMPORT
    | MEMORY
    | DATA
    | TABLE
    | ELEM
    | TAG
    | CONST
    | LET
    | RETURN
    | BR
    | BR_IF
    | BR_TABLE
    | THROW
    | THROW_REF
    | BECOME
    | NOP
    | UNREACHABLE => Leader
    EOF => Terminal
    _ => Skip
  }
}

///|
/// A parse that reports every syntax error it can resynchronize past.
///
/// The module is best-effort: whatever the actions built from the parts that
/// did parse, or `None` if recovery never got the automaton back to an accept.
pub fn parse_recover(src : String, fname? : String = "") -> ParseResult {
  let ctx = @trivia.Context::new()
  set_context(ctx)
  let lexed = @lexer.tokens_from_string(src, fname~, trivia_ctx=ctx)
  let errors = lexed.errors
  // A lexical error stops the scan, and there is no resuming lexer here yet, so
  // the tokens end where it stopped. Parsing them still reports the syntax
  // errors before that point.
  if lexed.tokens.length() == 0 {
    return { module_: None, errors, trivia: ctx, }
  }
  let module_ = drive_recovering(lexed.tokens, errors)
  match taken_error() {
    Some(SyntaxError(loc~, message~, hint~, fix~)) =>
      errors.push({ ..@basic.Report::error(loc, message), hint, edit: fix, })
    None => ()
  }
  errors.sort_by((a, b) => a.loc.start.cnum - b.loc.start.cnum)
  { module_, errors, trivia: ctx, }
}

///|
/// Give up after this many syntax errors in one file.
///
/// Every repair consumes a token or inserts one at a position it will not
/// insert at again, so the loop terminates on its own; this bounds the
/// diagnostic noise, not the loop.
const RECOVERY_LIMIT = 100

///|
/// The automaton, driven with repairs.
///
/// Mirrors the generated `yy_parse` decision for decision -- see state.mbt for
/// why that is a hand-copy -- with an `Error` arm that repairs instead of
/// raising.
fn drive_recovering(
  tokens : Array[(Token, Position, Position)],
  errors : Array[@basic.Report],
) -> @ast.LocModule? {
  let stack = [0]
  let data : Array[(YYObj, Position, Position)] = []
  let mut state = 0
  let mut cursor = 0
  let mut last_pos = tokens[0].1
  let mut lookahead : (Int, (YYObj, Position, Position), Token?)? = None
  // Tokens recovery has decided to splice in, taken before the real ones.
  let pending : Array[(Token, Position, Position)] = []
  // Where a token was last inserted. Inserting twice at one spot would loop
  // when the insertion does not actually unblock the parse.
  let mut last_insert = -1
  // The `;` symbol id, asked of the generated mapping rather than hard-coded:
  // symbol numbering is the generator's business and changes with the grammar.
  let (semi_symbol, _) = yy_input(SEMI, last_pos, last_pos)
  while errors.length() < RECOVERY_LIMIT {
    let decision = match yy_state(state, 0) {
      ReduceNoLookahead(_) | Accept as d => d
      _ =>
        match lookahead {
          Some(la) => yy_state(state, la.0)
          None =>
            if pending.length() > 0 {
              let (token, start_pos, end_pos) = pending.remove(0)
              let (sym, obj) = yy_input(token, start_pos, end_pos)
              lookahead = Some((sym, (obj, start_pos, end_pos), Some(token)))
              yy_state(state, sym)
            } else if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (sym, obj) = yy_input(token, start_pos, end_pos)
              lookahead = Some((sym, (obj, start_pos, end_pos), Some(token)))
              yy_state(state, sym)
            } else {
              lookahead = Some((0, (YYObj_Void, last_pos, last_pos), None))
              yy_state(state, 0)
            }
        }
    }
    match decision {
      Accept =>
        return match data.unsafe_pop().0 {
          YYObj__ast_LocModule(m) => Some(m)
          _ => None
        }
      Shift(next) => {
        guard lookahead is Some(la)
        data.push(la.1)
        stack.push(next)
        state = next
        last_pos = la.1.2
        lookahead = None
      }
      Reduce(count, symbol, action)
      | ReduceNoLookahead(count, symbol, action) => {
        let mut count = count
        let mut symbol = symbol
        let mut action = action
        while true {
          let args = data[data.length() - count:]
          let obj = action(last_pos, args)
          let span = if args.length() == 0 {
            (last_pos, last_pos)
          } else {
            (args[0].1, args[args.length() - 1].2)
          }
          for _ in 0..<count {
            data.unsafe_pop() |> ignore
            stack.unsafe_pop() |> ignore
          }
          state = stack[stack.length() - 1]
          data.push((obj, span.0, span.1))
          match yy_state(state, symbol) {
            Accept =>
              return match data.unsafe_pop().0 {
                YYObj__ast_LocModule(m) => Some(m)
                _ => None
              }
            Shift(next) => {
              stack.push(next)
              state = next
              break
            }
            Reduce(c, s, a) | ReduceNoLookahead(c, s, a) => {
              count = c
              symbol = s
              action = a
            }
            Error => return None
          }
        }
      }
      Error => {
        guard lookahead is Some((sym, (_, start, end), token)) else {
          return None
        }
        // The same report the non-recovering path builds, including the
        // reference's wording and its labels: `data` runs parallel to `stack`
        // (minus the bottom cell, which stands for no symbol), which is all
        // `ErrorState` needs to resolve them.
        let expected = expected_at(stack)
        let spans = [(tokens[0].1, tokens[0].1)]
        for d in data {
          spans.push((d.1, d.2))
        }
        let st : ErrorState = {
          state,
          stack: stack.copy(),
          spans,
          token_index: cursor - 1,
        }
        errors.push(syntax_report(st, tokens, { start, end, }, expected))

        // Repair 1: a `;` in front of the offending token -- but only if it
        // UNBLOCKS the parse. The state after `{` can shift a `;` (an empty
        // statement is legal), so acceptability alone would insert one in front
        // of any junk that follows an opening brace and report a missing
        // separator that was never missing.
        //
        // The caret goes where the `;` BELONGS -- just past the last token
        // shifted -- not on the token that exposed its absence, which is on the
        // next line as often as not.
        if last_pos.cnum != last_insert && unblocks(stack, semi_symbol, sym) {
          last_insert = last_pos.cnum
          errors[errors.length() - 1] = missing_semi_report(last_pos)
          pending.push((SEMI, last_pos, last_pos))
          pending.push((token.unwrap_or(EOF), start, end))
          lookahead = None
          continue
        }

        // Repair 2: auto-close. When the offending token is itself a
        // boundary -- a closer, a `;`, or end of input -- and is rejected
        // because a construct in front of it is still open, skipping would
        // unwind PAST that construct and discard it. Closing it instead keeps
        // the function the user is still typing in the tree, and gives the
        // error a quick fix that says what is missing.
        let held = token.unwrap_or(EOF)
        if sync_class(held) is (Close | Boundary | Terminal) {
          match auto_close(stack, sym) {
            Some(closers) => {
              let text = StringBuilder()
              for c in closers {
                pending.push((c.0, last_pos, last_pos))
                text.write_string(c.1)
              }
              pending.push((held, start, end))
              let at = errors[errors.length() - 1].loc
              errors[errors.length() - 1] = {
                ..errors[errors.length() - 1],
                edit: Some({
                  loc: { start: at.start, end: at.start, },
                  new_text: text.to_string(),
                }),
              }
              lookahead = None
              continue
            }
            None => ()
          }
        }

        // Repair 3: skip to a resynchronization point and unwind to it.
        guard resync(tokens, cursor - 1) is Some(at) else { return None }
        cursor = at + 1
        let (token, s, e) = tokens[at]
        let (sym, obj) = yy_input(token, s, e)
        // Unwind: the sync token belongs to some construct further down the
        // stack, and popping to it is what lets the parse continue there.
        while stack.length() > 1 && !acceptable(stack, sym) {
          stack.unsafe_pop() |> ignore
          data.unsafe_pop() |> ignore
        }
        if !acceptable(stack, sym) {
          return None
        }
        state = stack[stack.length() - 1]
        lookahead = Some((sym, (obj, s, e), Some(token)))
      }
    }
  }
  None
}

///|
/// Would inserting `candidate` let `held` through?
///
/// The validation the reference calls for: acceptability of the candidate is
/// not enough, since a `;` is acceptable in plenty of places where the real
/// problem is the token after it.
fn unblocks(stack : Array[Int], candidate : Int, held : Int) -> Bool {
  match shift_sim(stack, candidate) {
    None => false
    Some(after) => acceptable(after, held)
  }
}

///|
/// Closers that, inserted in order, make `held` acceptable.
///
/// A closer is always preferred; the separator only steps in to end a statement
/// that must be terminated before its block can close (`add(1, 2 }` needs `)`,
/// then `;`, then `}`). Every inserted closer shifts a closing bracket, which
/// strictly reduces the open nesting, so the loop is finite.
fn auto_close(stack : Array[Int], held : Int) -> Array[(Token, String)]? {
  let candidates : Array[(Token, String)] = [
    (RBRACE, "}"),
    (RPAREN, ")"),
    (RBRACKET, "]"),
    (SEMI, ";"),
  ]
  let nowhere : Position = { fname: "", lnum: 0, bol: 0, cnum: 0, }
  let inserted = []
  let mut cur = stack.copy()
  // Bounded by the nesting the stack can hold.
  for _ in 0..<cur.length() {
    if acceptable(cur, held) {
      return if inserted.length() > 0 { Some(inserted) } else { None }
    }
    let mut moved = false
    for c in candidates {
      let (sym, _) = yy_input(c.0, nowhere, nowhere)
      match shift_sim(cur, sym) {
        Some(next) => {
          cur = next
          inserted.push(c)
          moved = true
          break
        }
        None => ()
      }
    }
    if !moved {
      return None
    }
  }
  None
}

///|
/// `Missing ';'.`, with the quick fix that inserts one.
///
/// A zero-width span just before the offending token: that is where the `;`
/// belongs, and it is what the reference underlines.
fn missing_semi_report(at : Position) -> @basic.Report {
  {
    ..@basic.Report::error({ start: at, end: at, }, "Missing ';'."),
    edit: Some({ loc: { start: at, end: at, }, new_text: ";", }),
  }
}

///|
/// The next token recovery can resume at, from `from` onwards.
///
/// Nesting-aware: an opener met while skipping descends a level and its closer
/// ascends again, so a `;` or `}` that closes something opened INSIDE the
/// skipped span does not resync the construct the error is in. A `Leader`
/// resyncs at any depth, because an unbalanced opener must not swallow the
/// next item.
fn resync(tokens : Array[(Token, Position, Position)], from : Int) -> Int? {
  let mut depth = 0
  for i in from..<tokens.length() {
    match sync_class(tokens[i].0) {
      Open => depth += 1
      Close =>
        if depth == 0 {
          if i > from {
            return Some(i)
          }
        } else {
          depth -= 1
        }
      Boundary => if depth == 0 && i > from { return Some(i) }
      Leader => if i > from { return Some(i) }
      // End of input is a resync point of last resort: the parse can still
      // reduce what it has and report what is missing.
      Terminal => return Some(i)
      Skip => ()
    }
  }
  None
}
