// Tests for the configuration explorer.
//
// The behaviour worth pinning is what the driver exists for: a module with
// conditionals is a family of programs, and a diagnostic has to be reported
// once with the assumption that reaches it -- not once per configuration that
// happened to produce it.

///|
fn loc_at(start : Int, end_ : Int) -> @basic.Location {
  {
    start: { fname: "t.wax", lnum: 1, bol: 0, cnum: start },
    end: { fname: "t.wax", lnum: 1, bol: 0, cnum: end_ },
  }
}

///|
fn var_(name : String) -> @wasm_types.Cond {
  Var({ desc: name, info: loc_at(0, 0) })
}

///|
/// Render what the driver reported, one line per diagnostic.
fn reported(ctx : @diagnostic.Context) -> String {
  ctx
  .collected()
  .map(d => {
    let hint = match d.hint {
      None => ""
      Some(h) => "  [" + @message.to_plain_string(h) + "]"
    }
    "\{d.loc.start.cnum}: \{@message.to_plain_string(d.message)}\{hint}"
  })
  .join("\n")
}

///|
/// With no conditional at all there is one configuration, and a diagnostic in
/// it carries no "reachable when" -- it is reachable full stop.
test "a module with no conditionals" {
  let ctx = @diagnostic.collector()
  @cond_explore.check_all(
    ctx,
    specialize=(_env, _asm, _enqueue, _record) => 0,
    check=(cctx, _cfg) => {
      cctx.report(loc_at(5, 7), Error, @message.text("boom"))
    },
  )
  inspect(reported(ctx), content="5: boom")
}

///|
/// Two branches, and a complaint in only one of them. It is reported once, and
/// says which branch reaches it.
test "a diagnostic in one branch names its assumption" {
  let ctx = @diagnostic.collector()
  @cond_explore.check_all(
    ctx,
    specialize=(env, assumed, enqueue, record) => {
      let c = env.of_cond(@diagnostic.collector(), loc_at(0, 0), var_("debug"))
      // Undetermined: take the positive branch and leave the negative one.
      if @cond.is_satisfiable(@cond.and_(assumed, c)) &&
        !@cond.logical_implies(assumed, c) {
        enqueue(@cond.and_(assumed, @cond.not_(c)))
        record(c)
        true
      } else {
        record(
          if @cond.logical_implies(assumed, c) {
            c
          } else {
            @cond.not_(c)
          },
        )
        @cond.logical_implies(assumed, c)
      }
    },
    check=(cctx, cfg) => {
      if cfg {
        cctx.report(loc_at(5, 7), Error, @message.text("only when debug"))
      }
    },
  )
  inspect(reported(ctx), content="5: only when debug  [reachable when $debug]")
}

///|
/// The same complaint from BOTH branches is one diagnostic, and its
/// reachability is their union -- which is everything, so there is nothing to
/// qualify it with.
test "a diagnostic in every branch is reported once, unqualified" {
  let ctx = @diagnostic.collector()
  @cond_explore.check_all(
    ctx,
    specialize=(env, assumed, enqueue, record) => {
      let c = env.of_cond(@diagnostic.collector(), loc_at(0, 0), var_("debug"))
      if @cond.is_satisfiable(@cond.and_(assumed, c)) &&
        !@cond.logical_implies(assumed, c) {
        enqueue(@cond.and_(assumed, @cond.not_(c)))
        record(c)
        true
      } else {
        record(
          if @cond.logical_implies(assumed, c) {
            c
          } else {
            @cond.not_(c)
          },
        )
        @cond.logical_implies(assumed, c)
      }
    },
    // Complains in both branches, at the same place and in the same words.
    check=(cctx, _cfg) => {
      cctx.report(loc_at(5, 7), Error, @message.text("always"))
    },
  )
  inspect(reported(ctx), content="5: always")
}

///|
/// Diagnostics come out in source order, whatever order exploration found them
/// in.
test "reports are sorted by position" {
  let ctx = @diagnostic.collector()
  @cond_explore.check_all(
    ctx,
    specialize=(_env, _asm, _enqueue, _record) => 0,
    check=(cctx, _cfg) => {
      cctx.report(loc_at(30, 31), Error, @message.text("third"))
      cctx.report(loc_at(10, 11), Error, @message.text("first"))
      cctx.report(loc_at(20, 21), Error, @message.text("second"))
    },
  )
  inspect(
    reported(ctx),
    content=(
      #|10: first
      #|20: second
      #|30: third
    ),
  )
}

///|
/// A `universal` diagnostic -- an unused local, say -- claims something about
/// every configuration, so it survives only if every configuration produced it.
/// Being unused in one branch and used in another is not being unused.
test "a universal diagnostic must hold everywhere" {
  fn run(only_in_one : Bool) -> String {
    let ctx = @diagnostic.collector()
    @cond_explore.check_all(
      ctx,
      specialize=(env, assumed, enqueue, record) => {
        let c = env.of_cond(
          @diagnostic.collector(),
          loc_at(0, 0),
          var_("debug"),
        )
        if @cond.is_satisfiable(@cond.and_(assumed, c)) &&
          !@cond.logical_implies(assumed, c) {
          enqueue(@cond.and_(assumed, @cond.not_(c)))
          record(c)
          true
        } else {
          record(
            if @cond.logical_implies(assumed, c) {
              c
            } else {
              @cond.not_(c)
            },
          )
          @cond.logical_implies(assumed, c)
        }
      },
      check=(cctx, cfg) => {
        if cfg || !only_in_one {
          cctx.report(
            loc_at(5, 7),
            Warning,
            @message.text("unused"),
            universal=true,
          )
        }
      },
    )
    reported(ctx)
  }

  // Unused in both configurations: genuinely unused.
  inspect(run(false), content="5: unused")
  // Unused in one only: not unused, and nothing is reported.
  inspect(run(true), content="")
}
