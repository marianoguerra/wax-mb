// Which automaton state a parse failed in.
//
// MoonYacc's error value is `UnexpectedToken(Token, span, Array[TokenKind])`:
// the offending token, where it is, and what could have been shifted. It does
// not say WHERE IN THE AUTOMATON the parser was, and that is the one thing a
// per-state message table has to key on -- "Assuming that the argument list is
// complete" is a property of the state, not of the token set (two states with
// identical acceptable tokens routinely mean different things: an expression,
// a then-branch and an index expression all start the same way).
//
// The generated parser is built with `--table` (see moon.pkg), so a state IS an
// Int, and `yy_state`/`yy_input` are package-visible. What is missing is only a
// way to observe the state at the moment of failure -- so this replays the
// token stream through the same tables with the semantic actions left out, and
// stops where the real parse stopped.
//
// Replaying is not free, but it happens once per FAILING file, which is the one
// case where nothing else is being done with the time.

///|
/// Where a parse ran aground, in the automaton's terms.
pub struct ErrorState {
  /// The state whose action on the offending token was `Error`.
  state : Int
  /// The state stack when that happened, bottom first, `state` last.
  ///
  /// Kept because the reference's diagnostics point at enclosing constructs by
  /// stack DEPTH (`<2>This '(' opens the enclosing construct.`), so resolving
  /// those labels means indexing this.
  stack : Array[Int]
  /// Index into the token array of the offending token, or the array's length
  /// when the input ended early.
  token_index : Int
  /// The source span each stack cell covers, parallel to `stack`.
  ///
  /// A cell holds one grammar symbol: a shifted token's own span, or, for a
  /// cell a reduction pushed, the span of everything that reduction consumed.
  /// That is what makes "this statement" underlineable -- the completed
  /// construct is a cell, and the cell knows where it starts.
  ///
  /// The bottom cell is the automaton's start state, which stands for no
  /// symbol; its span is empty.
  spans : Array[(Position, Position)]
}

///|
/// Replay `tokens` through the automaton and report where it fails.
///
/// `None` when the input parses -- callers only ask after a real parse has
/// already failed, so `None` means the replay disagrees with the parse, and the
/// caller falls back rather than trusting a state it cannot explain.
///
/// Mirrors the generated `yy_parse` decision for decision. The differences are
/// that nothing is built (no data stack, no actions run, so a grammar action's
/// side effects cannot fire twice) and that the loop reports the failure rather
/// than raising.
pub fn error_state(tokens : Array[(Token, Position, Position)]) -> ErrorState? {
  let stack = [0]
  // Spans run parallel to `stack`, mirroring what `yy_parse` keeps on its data
  // stack. The bottom cell stands for no symbol.
  let origin = tokens[0].1
  let spans = [(origin, origin)]
  let mut last_pos = origin
  let mut state = 0
  let mut cursor = 0
  // The lookahead SYMBOL, once read. Symbol 0 doubles as "no lookahead needed"
  // when probing a state and as the end-of-input symbol, exactly as in
  // `yy_parse`.
  let mut lookahead : Int? = None
  while true {
    let decision = match yy_state(state, 0) {
      ReduceNoLookahead(_) | Accept as d => d
      _ =>
        match lookahead {
          Some(sym) => yy_state(state, sym)
          None =>
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (sym, _) = yy_input(token, start_pos, end_pos)
              lookahead = Some(sym)
              yy_state(state, sym)
            } else {
              lookahead = Some(0)
              yy_state(state, 0)
            }
        }
    }
    match decision {
      Accept => return None
      Shift(next) => {
        let (_, start_pos, end_pos) = tokens[cursor - 1]
        stack.push(next)
        spans.push((start_pos, end_pos))
        last_pos = end_pos
        state = next
        lookahead = None
      }
      Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
        // A reduction can chain: popping exposes a state that reduces again.
        let mut count = count
        let mut symbol = symbol
        while true {
          // The reduced symbol covers everything it consumed. An empty
          // production covers nothing, and sits where the parser stands --
          // which is how the reference decides an epsilon subject is not worth
          // underlining.
          let mut span = (last_pos, last_pos)
          if count > 0 {
            span = (
              spans[spans.length() - count].0,
              spans[spans.length() - 1].1,
            )
          }
          for _ in 0..<count {
            stack.unsafe_pop() |> ignore
            spans.unsafe_pop() |> ignore
          }
          state = stack[stack.length() - 1]
          match yy_state(state, symbol) {
            Accept => return None
            Shift(next) => {
              stack.push(next)
              spans.push(span)
              state = next
              break
            }
            Reduce(c, s, _) | ReduceNoLookahead(c, s, _) => {
              count = c
              symbol = s
            }
            // The goto for a symbol just reduced is always defined; reaching
            // here would mean the tables disagree with themselves.
            Error => return None
          }
        }
      }
      Error =>
        return Some({
          state,
          stack: stack.copy(),
          spans: spans.copy(),
          token_index: if lookahead is Some(0) && cursor >= tokens.length() {
            tokens.length()
          } else {
            cursor - 1
          },
        })
    }
  }
  None
}

///|
/// The construct the parser was in the middle of, as a span.
///
/// The reference's `Assuming that the X is complete` messages carry a label
/// pointing AT that X. Menhir names it by the reductions it performs once the
/// error token is in hand -- annotated `%on_error_reduce` -- and the completed
/// construct is what the outermost of them pushes.
///
/// Nothing here has those annotations, so this reduces while the reduction is
/// unambiguous: a state whose only reduce action, over every terminal
/// lookahead, is one production. That is the same move for the same reason, and
/// where it is not the same the span simply does not match the reference's and
/// the label is dropped (see the calibration in tools/gen_parser_messages.py).
///
/// `None` when the stack does not reduce at all, or when the construct is
/// empty -- underlining nothing is noise, which is the rule the reference
/// applies to an epsilon reduction too.
pub fn ErrorState::subject_span(self : Self) -> (Position, Position)? {
  let stack = self.stack.copy()
  let spans = self.spans.copy()
  let mut reduced = false
  while true {
    guard sole_reduction(stack[stack.length() - 1]) is Some((count, symbol)) else {
      break
    }
    // Never eat the bottom cell: it stands for the whole parse, not a
    // construct.
    if count >= stack.length() {
      break
    }
    let span = if count > 0 {
      (spans[spans.length() - count].0, spans[spans.length() - 1].1)
    } else {
      (spans[spans.length() - 1].1, spans[spans.length() - 1].1)
    }
    for _ in 0..<count {
      stack.unsafe_pop() |> ignore
      spans.unsafe_pop() |> ignore
    }
    guard yy_state(stack[stack.length() - 1], symbol) is Shift(next) else {
      break
    }
    stack.push(next)
    spans.push(span)
    reduced = true
  }
  guard reduced else { return None }
  let span = spans[spans.length() - 1]
  if span.0.cnum >= span.1.cnum {
    None
  } else {
    Some(span)
  }
}

///|
/// The one production a state reduces by, if it has exactly one.
///
/// Probes every terminal lookahead. A goto (a nonterminal column) is a shift
/// and cannot be confused with a reduction, so the terminal range is only a
/// bound on the work, not on correctness.
fn sole_reduction(state : Int) -> (Int, Int)? {
  let mut found : (Int, Int)? = None
  let last = terminal_symbol_count + 1
  for sym in 1..<last {
    match yy_state(state, sym) {
      Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) =>
        match found {
          None => found = Some((count, symbol))
          Some((c, s)) => if c != count || s != symbol { return None }
        }
      _ => ()
    }
  }
  found
}

///|
/// How many terminals the grammar declares, which is how many symbol columns
/// at the front of a state's row are lookaheads rather than gotos.
///
/// Pinned by a test against the generated `yy_input`, which numbers the
/// terminals in declaration order from 1.
let terminal_symbol_count = 119

///|
/// The innermost delimiter still open at the failure.
///
/// The reference's `This '{' opens the enclosing construct.` label points at
/// the opener of the construct the error is inside. It reaches it through a
/// parser-stack cell; the same token is what a bracket scan of everything
/// shifted so far finds, so that is what this does -- and it needs no
/// correspondence between two automata's stack layouts.
///
/// `None` when nothing is open, which is when the reference emits no such
/// label either.
pub fn enclosing_opener(
  tokens : Array[(Token, Position, Position)],
  before : Int,
) -> (Position, Position)? {
  let open = []
  let last = @cmp.minimum(before, tokens.length())
  for i in 0..<last {
    match tokens[i].0 {
      LPAREN | LBRACKET | LBRACE => open.push(i)
      RPAREN | RBRACKET | RBRACE =>
        if open.length() > 0 {
          open.unsafe_pop() |> ignore
        }
      _ => ()
    }
  }
  if open.length() == 0 {
    None
  } else {
    let i = open[open.length() - 1]
    Some((tokens[i].1, tokens[i].2))
  }
}

///|
/// Would this symbol be shifted, given this stack?
///
/// The same walk the generated `error()` does to build its expected set: ask
/// the top state, and where it says reduce, perform the reduction on a COPY of
/// the stack and ask again. It answers for the stack, not just for the top
/// state, which is what "can the parser accept a `;` here" has to mean --
/// after a complete statement the `;` is shiftable only once the statement has
/// been reduced.
fn acceptable(stack : Array[Int], symbol : Int) -> Bool {
  shift_sim(stack, symbol) is Some(_)
}

///|
/// The state stack this one becomes if `symbol` is shifted, or None if it
/// cannot be.
///
/// The reductions the shift implies are performed on a copy, so this doubles as
/// the acceptability test AND as the "what if" recovery needs: whether
/// inserting a `;` would let the offending token through is a question about
/// the stack AFTER the `;`.
fn shift_sim(stack : Array[Int], symbol : Int) -> Array[Int]? {
  let s = stack.copy()
  // Every step either answers or pops at least one cell and pushes one goto,
  // and the automaton has no reduction cycles -- the fuel is a backstop
  // against a table that disagrees, not part of the algorithm.
  let mut fuel = 4 * stack.length() + 64
  while fuel > 0 {
    fuel -= 1
    match yy_state(s[s.length() - 1], symbol) {
      Accept => return Some(s)
      Shift(next) => {
        s.push(next)
        return Some(s)
      }
      Error => return None
      Reduce(count, lhs, _) | ReduceNoLookahead(count, lhs, _) => {
        let mut count = count
        let mut lhs = lhs
        let mut shifted = false
        while !shifted && fuel > 0 {
          fuel -= 1
          if count >= s.length() {
            return None
          }
          for _ in 0..<count {
            s.unsafe_pop() |> ignore
          }
          match yy_state(s[s.length() - 1], lhs) {
            Shift(next) => {
              s.push(next)
              shifted = true
            }
            Reduce(c, l, _) | ReduceNoLookahead(c, l, _) => {
              count = c
              lhs = l
            }
            _ => return None
          }
        }
      }
    }
  }
  None
}

///|
/// The terminals this stack could shift.
///
/// What `UnexpectedToken` carries -- recomputed, because recovery needs it
/// without an exception to catch. The generated `error()` builds exactly this
/// set, so it is asked rather than reimplemented: it raises, and the raise is
/// caught for the payload.
fn expected_at(stack : Array[Int]) -> Array[TokenKind] {
  let mut cells : @list.List[Int] = @list.empty()
  for s in stack {
    cells = @list.cons(s, cells)
  }
  let nowhere : Position = { fname: "", lnum: 0, bol: 0, cnum: 0 }
  try {
    error(cells, None, (nowhere, nowhere))
    ([] : Array[TokenKind])
  } catch {
    UnexpectedToken(_, _, expected) | UnexpectedEndOfInput(_, expected) =>
      expected
  } noraise {
    _ => []
  }
}
