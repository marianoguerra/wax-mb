// The layout engine: a stateful token consumer with bounded lookahead.
//
// A decision that needs to look ahead -- opening a GHv group, or a soft break
// inside a Fill group -- waits until enough tokens are buffered to resolve it.
// Because the fit scan short-circuits once the available column is exhausted,
// the queue stays bounded by roughly the target width. Everything else is laid
// out immediately.

///|
/// The suspended state of a fit scan that ran out of buffered input.
///
/// One record, mutated in place, so suspending allocates nothing. `ghv`
/// distinguishes a GHv group open (which resolves to a frame) from a Fill
/// break (which resolves to a separator); the rest are the parked loop
/// variables.
priv struct ScanState {
  mut active : Bool
  mut ghv : Bool
  mut base : Int
  mut str : BreakStrength
  mut avail : Int
  mut sstack : Array[Mode]
  mut fr : Array[Frame]
  mut ib : Int
  mut i : Int
}

///|
/// The engine.
struct Engine {
  width : Int
  out : StringBuilder
  /// How far breaks may indent, so deeply nested code does not march off the
  /// right margin. The analogue of Format's max_indent.
  max_indent : Int
  mut col : Int
  mut emitted : Bool
  /// A pending line break: indent, and whether a blank line precedes it.
  mut pend_line : (Int, Bool)?
  /// A pending flat separator. A line break supersedes one.
  mut pend_flat : BreakStrength?
  /// Innermost frame LAST, so push/pop are array operations.
  frames : Array[Frame]
  /// The lookahead FIFO.
  queue : Array[Token]
  mut qhd : Int
  /// > 0 while dropping the content of an if_broken whose enclosing group is
  /// not broken -- the trailing comma of a flat list.
  mut skip_depth : Int
  sc : ScanState
  mut scan_at_end : Bool
  /// Drop every token instead of laying it out. See `run_discard`.
  mut discarding : Bool
  /// When set, every fed token is appended here before being laid out.
  ///
  /// The builder is engine-independent, so a recorded stream is the exact
  /// input an ALTERNATIVE layout engine would receive -- which is what lets
  /// `printer_pp` be compared against this one on the same document rather
  /// than on a re-derived approximation of it. See `run_tokens`.
  mut record : Array[Token]?
}

///|
pub fn Engine::new(width? : Int = 78) -> Engine {
  {
    width,
    out: StringBuilder::new(),
    max_indent: if width - 10 > 0 {
      width - 10
    } else {
      0
    },
    col: 0,
    emitted: false,
    pend_line: None,
    pend_flat: None,
    frames: [{ findent: 0, fmode: Brkm }],
    queue: [],
    qhd: 0,
    skip_depth: 0,
    sc: {
      active: false,
      ghv: false,
      base: 0,
      str: Space,
      avail: 0,
      sstack: [],
      fr: [],
      ib: 0,
      i: 0,
    },
    scan_at_end: false,
    discarding: false,
    record: None,
  }
}

///|
fn Engine::qn(self : Engine) -> Int {
  self.queue.length() - self.qhd
}

///|
fn Engine::qget(self : Engine, i : Int) -> Token {
  self.queue[self.qhd + i]
}

///|
fn Engine::qpop(self : Engine) -> Token {
  let x = self.queue[self.qhd]
  self.qhd += 1
  // Compact once the consumed prefix dominates, so the array does not grow
  // without bound over a long document.
  if self.qhd > 64 && self.qhd * 2 > self.queue.length() {
    let rest = self.queue[self.qhd:].to_owned()
    self.queue.clear()
    for t in rest {
      self.queue.push(t)
    }
    self.qhd = 0
  }
  x
}

///|
fn Engine::cur(self : Engine) -> Frame {
  self.frames[self.frames.length() - 1]
}

///|
/// Emit any pending break, then reset it.
///
/// A leading break before any output is suppressed, so a document never starts
/// with a blank line.
fn Engine::flush(self : Engine) -> Unit {
  match self.pend_line {
    Some((ind, blank)) =>
      if self.emitted {
        self.out.write_char('\n')
        if blank {
          self.out.write_char('\n')
        }
        for _ in 0..<ind {
          self.out.write_char(' ')
        }
        self.col = ind
      }
    None =>
      match self.pend_flat {
        Some(s) =>
          if s.strength() >= BreakStrength::Space.strength() {
            self.out.write_char(' ')
            self.col += 1
          }
        None => ()
      }
  }
  self.pend_line = None
  self.pend_flat = None
}

///|
fn Engine::break_line(self : Engine, ind : Int, blank : Bool) -> Unit {
  let ind = if ind > self.max_indent { self.max_indent } else { ind }
  self.pend_line = match self.pend_line {
    Some((_, b0)) => Some((ind, b0 || blank))
    None => Some((ind, blank))
  }
  self.pend_flat = None
}

///|
fn Engine::flat_sep(self : Engine, s : BreakStrength) -> Unit {
  if self.pend_line is None {
    self.pend_flat = Some(
      match self.pend_flat {
        Some(s0) => if s.strength() >= s0.strength() { s } else { s0 }
        None => s
      },
    )
  }
}

///|
/// The column the next text would land in, accounting for pending breaks.
fn Engine::eff_col(self : Engine) -> Int {
  match self.pend_line {
    Some((ind, _)) => ind
    None => self.col + (if self.pend_flat is Some(_) { 1 } else { 0 })
  }
}

///|
/// Does the content fit in `avail` columns, up to the next line-ending break?
///
/// Trailing context BEYOND the immediate group is included -- this is not a
/// local "does this group alone fit" check, which is what makes a group's
/// decision account for what follows it on the line.
///
/// `sstack` is the mode stack of groups entered during the scan (innermost
/// last), all Flat; beneath them `fr` is the enclosing frame stack. A break
/// ends the line iff the mode in force is a breaking one.
fn Engine::scan_go(
  self : Engine,
  avail_in : Int,
  sstack : Array[Mode],
  fr : Array[Frame],
  ib_in : Int,
  i_in : Int,
) -> ScanResult {
  let mut avail = avail_in
  let mut ib = ib_in
  let mut i = i_in
  for ;; {
    if avail < 0 {
      return Nofit
    }
    if i >= self.qn() {
      if self.scan_at_end {
        return Fits
      }
      // Out of buffered input: park the loop state for the next feed.
      self.sc.avail = avail
      self.sc.sstack = sstack
      self.sc.fr = fr
      self.sc.ib = ib
      self.sc.i = i
      return Susp
    }
    let tok = self.qget(i)
    if ib > 0 {
      // Dropping if_broken content: measure nothing.
      ib = match tok {
        TBegin(_) | TNest(_) | TIfBroken => ib + 1
        TEnd => ib - 1
        _ => ib
      }
      i += 1
      continue
    }
    // The mode in force: innermost scanned group, else the innermost frame.
    let mode = if sstack.length() > 0 {
      sstack[sstack.length() - 1]
    } else if fr.length() > 0 {
      fr[fr.length() - 1].fmode
    } else {
      Brkm
    }
    match tok {
      TText(w, _) => avail -= w
      TBegin(_) => sstack.push(Flat)
      TNest(_) => sstack.push(mode)
      TIfBroken => ib = 1
      TEnd =>
        if sstack.length() > 0 {
          sstack.unsafe_pop() |> ignore
        } else if fr.length() > 1 {
          fr.unsafe_pop() |> ignore
        } else {
          // Popped past the outermost frame.
          return Fits
        }
      TBreak(b) =>
        match mode {
          Brkm | Fill => return Fits
          Flat =>
            match b {
              Newline | BlankLine => return Nofit
              Space => avail -= 1
              Cut => ()
            }
        }
    }
    i += 1
  }
}

///|
/// Commit a resolved decision and pop the token that prompted it.
fn Engine::resolve_decision(self : Engine, fit : Bool) -> Unit {
  self.sc.active = false
  self.qpop() |> ignore
  if self.sc.ghv {
    self.frames.push({
      findent: self.sc.base,
      fmode: if fit {
        Flat
      } else {
        Brkm
      },
    })
  } else if fit {
    self.flat_sep(self.sc.str)
  } else {
    self.break_line(self.cur().findent, false)
  }
}

///|
/// Lay out a token that needs no lookahead.
fn Engine::process(self : Engine, tok : Token) -> Unit {
  match tok {
    TText(w, s) => {
      self.flush()
      self.out.write_string(s)
      self.emitted = true
      self.col += w
    }
    TNest(n) => {
      let c = self.cur()
      self.frames.push({ findent: c.findent + n, fmode: c.fmode })
    }
    TBegin(k) => {
      // A group's break-indentation is measured from the COLUMN WHERE IT OPENS
      // (Format semantics), not from the inherited nesting. The two differ when
      // a group starts mid-line, so the group rebases to the open column.
      let base = self.eff_col()
      let m = match k {
        GV => Brkm
        GH => Flat
        GBox | GHov => Fill
        // GHv is resolved with lookahead in `advance` and never reaches here.
        GHv => Brkm
      }
      self.frames.push({ findent: base, fmode: m })
    }
    TIfBroken => {
      // Only reached when the enclosing group is broken; the flat case is
      // skipped in `advance`.
      let c = self.cur()
      self.frames.push({ findent: c.findent, fmode: c.fmode })
    }
    TEnd => if self.frames.length() > 1 { self.frames.unsafe_pop() |> ignore }
    TBreak(str) => {
      let c = self.cur()
      match (str, c.fmode) {
        (Newline, _) => self.break_line(c.findent, false)
        (BlankLine, _) => self.break_line(c.findent, true)
        (Cut, Flat) | (Space, Flat) => self.flat_sep(str)
        (Cut, Brkm) | (Space, Brkm) => self.break_line(c.findent, false)
        // Fill soft breaks are resolved with lookahead in `advance`.
        (Cut, Fill) | (Space, Fill) => self.break_line(c.findent, false)
      }
    }
  }
}

///|
/// Drain the queue front while each front token is resolvable.
///
/// A decision scans the lookahead from index 1, past the front token itself. If
/// it cannot yet decide, it is left suspended and resumed on the next feed.
fn Engine::advance(self : Engine, at_end~ : Bool) -> Unit {
  self.scan_at_end = at_end
  for ;; {
    if self.skip_depth > 0 {
      if self.qn() == 0 {
        return
      }
      match self.qpop() {
        TBegin(_) | TNest(_) | TIfBroken => self.skip_depth += 1
        TEnd => self.skip_depth -= 1
        _ => ()
      }
      continue
    }
    if self.qn() == 0 {
      return
    }
    if self.sc.active {
      // Resume the suspended front decision from its parked state.
      match
        self.scan_go(
          self.sc.avail,
          self.sc.sstack,
          self.sc.fr,
          self.sc.ib,
          self.sc.i,
        ) {
        Susp => return
        Fits => self.resolve_decision(true)
        Nofit => self.resolve_decision(false)
      }
      continue
    }
    match self.qget(0) {
      TBegin(GHv) => {
        let base = self.eff_col()
        // Set before the scan, so the immediately-resolved case sees them too.
        self.sc.ghv = true
        self.sc.base = base
        match
          self.scan_go(self.width - base, [Flat], self.frames.copy(), 0, 1) {
          Susp => {
            self.sc.active = true
            return
          }
          Fits => self.resolve_decision(true)
          Nofit => self.resolve_decision(false)
        }
      }
      TBreak(str) =>
        if (str is Cut || str is Space) && self.cur().fmode == Fill {
          // Kept flat, this separator occupies a column itself, so what follows
          // starts one further right. Account for it.
          let sep = if str is Space { 1 } else { 0 }
          self.sc.ghv = false
          self.sc.str = str
          match
            self.scan_go(
              self.width - self.eff_col() - sep,
              [],
              self.frames.copy(),
              0,
              1,
            ) {
            Susp => {
              self.sc.active = true
              return
            }
            Fits => self.resolve_decision(true)
            Nofit => self.resolve_decision(false)
          }
        } else {
          let tok = self.qpop()
          self.process(tok)
        }
      TIfBroken =>
        if self.cur().fmode != Brkm {
          self.qpop() |> ignore
          self.skip_depth = 1
        } else {
          let tok = self.qpop()
          self.process(tok)
        }
      _ => {
        let tok = self.qpop()
        self.process(tok)
      }
    }
  }
}

///|
/// Push one token.
fn Engine::feed(self : Engine, tok : Token) -> Unit {
  match self.record {
    Some(r) => r.push(tok)
    None => ()
  }
  if self.discarding {
    return
  }
  self.queue.push(tok)
  self.advance(at_end=false)
}

///|
/// Signal end of input and drain the tail.
fn Engine::finish_stream(self : Engine) -> Unit {
  self.advance(at_end=true)
}

///|
/// The laid-out text.
fn Engine::contents(self : Engine) -> String {
  self.out.to_string()
}
