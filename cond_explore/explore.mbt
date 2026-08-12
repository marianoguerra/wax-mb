// Checking a module that has conditional annotations in it.
//
// Ported from wax/src/lib-wasm/cond_explore.ml.
//
// A module with `#[if]` in it is not one program but a family of them, and a
// diagnostic is only meaningful together with the assumption under which it is
// reachable. So the driver explores every reachable configuration, runs the
// caller's check on each, and then reports each distinct diagnostic ONCE --
// annotated with the assumption that reaches it, rather than repeated per
// configuration that happened to produce it.
//
// Shared by the WAT validator and the Wax type checker, which is why the
// checking half is a callback rather than anything this module knows about.

///|
/// How many configurations to explore before giving up.
///
/// A module with n independent conditionals has 2^n of them, so a cap is not
/// optional. Hitting it is reported rather than passed over: a truncated
/// exploration has checked a subset, and saying so is the difference between
/// "no errors" and "no errors found so far".
pub let max_configurations : Int = 4096

///|
/// One diagnostic, and the assumption under which it is reachable.
priv struct Reachable {
  diagnostic : @diagnostic.Diagnostic
  mut reach : @cond.T
}

///|
/// Explore every reachable configuration, check each, and report the union.
///
/// `specialize` resolves each conditional against the current assumption to
/// produce a conditional-free configuration. Where a conditional is not decided
/// by the assumption it picks one branch, `enqueue`s the assumption for the
/// other, and `record`s the chosen branch's condition so the configuration's
/// own full assumption can be accumulated.
///
/// `explain` renders an assumption for the "reachable when" hint; it is a
/// parameter because the two callers spell conditions in different surface
/// syntaxes.
pub fn[Cfg] check_all(
  diagnostics : @diagnostic.Context,
  specialize~ : (@cond.Env, @cond.T, (@cond.T) -> Unit, (@cond.T) -> Unit) -> Cfg,
  check~ : (@diagnostic.Context, Cfg) -> Unit,
  truncation_location? : @basic.Location? = None,
  explain? : ((@cond.Env, @cond.T) -> String?)? = None,
) -> Unit {
  let explain = match explain {
    Some(f) => f
    None => (env, c) => env.explain(c)
  }
  // A fresh solver state per call, so interning never leaks between modules
  // processed in the same run.
  let env = @cond.Env::new()
  let queue : Array[@cond.T] = [@cond.true_]
  let mut head = 0
  let processed : Map[String, Unit] = Map([])
  // Keyed by location and message, so the same complaint from several
  // configurations folds into one entry whose reachability is their union.
  let errors : Map[String, Reachable] = Map([])
  let order : Array[String] = []
  let mut count = 0
  let mut truncated = false
  // The union of every reachable configuration's assumption: the whole feasible
  // space. A `universal` diagnostic -- an unused local, say -- is only true if
  // it holds across all of it, since being unused in some branches and used in
  // others is not being unused.
  let mut feasible = @cond.false_
  while head < queue.length() && !truncated {
    let assumption = queue[head]
    head += 1
    let key = @cond.canonical_key(assumption)
    if processed.contains(key) || !@cond.is_satisfiable(assumption) {
      continue
    }
    if count >= max_configurations {
      truncated = true
      continue
    }
    processed[key] = ()
    count += 1
    let mut full = @cond.true_
    let cfg = specialize(env, assumption, b => queue.push(b), lit => {
      full = @cond.and_(full, lit)
    })
    // Each configuration is checked in its own collector, derived from the
    // parent so it inherits the error-recovery mode: the unbound-name cascade
    // suppression then applies to a module recovered past syntax errors here
    // just as it does on the conditional-free path.
    let cctx = @diagnostic.collector(parent=Some(diagnostics))
    check(cctx, cfg)
    // A backstop. `specialize` prunes unreachable branches as it goes, so a
    // configuration's full assumption is normally satisfiable; this discards
    // the diagnostics of an infeasible one should any residual incompleteness
    // let it through.
    if !@cond.is_satisfiable(full) {
      continue
    }
    feasible = @cond.or_(feasible, full)
    for d in cctx.collected() {
      let k = "\{d.loc.start.cnum}:\{d.loc.end.cnum}:\{@message.to_plain_string(d.message)}"
      match errors.get(k) {
        Some(existing) => existing.reach = @cond.or_(existing.reach, full)
        None => {
          errors[k] = { diagnostic: d, reach: full }
          order.push(k)
        }
      }
    }
  }

  // Report in source order, which the exploration order is not.
  let entries = order.map(k => errors[k])
  entries.sort_by((a, b) => {
    let c = a.diagnostic.loc.start.cnum - b.diagnostic.loc.start.cnum
    if c != 0 {
      c
    } else {
      a.diagnostic.loc.end.cnum - b.diagnostic.loc.end.cnum
    }
  })
  for e in entries {
    let d = e.diagnostic
    // A universal diagnostic has to hold everywhere, and carries no "reachable
    // when" qualifier because there is no assumption to state.
    if d.universal && !@cond.logical_implies(feasible, e.reach) {
      continue
    }
    let hint = if d.universal {
      d.hint
    } else {
      match explain(env, e.reach) {
        None => d.hint
        Some(s) => {
          let reach = @message.text("reachable when " + s)
          match d.hint {
            Some(h) => Some(h.sep(reach))
            None => Some(reach)
          }
        }
      }
    }
    diagnostics.report(
      d.loc,
      d.severity,
      d.message,
      warning=d.warning,
      hint~,
      related=d.related,
    )
  }
  if truncated && truncation_location is Some(location) {
    diagnostics.report(
      location,
      Warning,
      @message.text("Too many conditional configurations (over")
      .sep(@message.int(max_configurations))
      .seq(@message.text("); coverage was truncated.")),
      warning=Some(TruncatedCoverage),
    )
  }
}
