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
        stack.push(next)
        state = next
        lookahead = None
      }
      Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
        // A reduction can chain: popping exposes a state that reduces again.
        let mut count = count
        let mut symbol = symbol
        while true {
          for _ in 0..<count {
            stack.unsafe_pop() |> ignore
          }
          state = stack[stack.length() - 1]
          match yy_state(state, symbol) {
            Accept => return None
            Shift(next) => {
              stack.push(next)
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
