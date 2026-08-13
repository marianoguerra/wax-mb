// The reporting context: policy resolution, queueing, and flushing.

///|
/// Where and how a context renders.
///
/// Held only by a RENDERING context; a collector has none, since it merely
/// accumulates entries for a rendering context to re-report later.
struct Render {
  theme : Theme
  output : Sink
  format : OutputFormat
  exit_on_error : Bool
}

///|
/// A reporting context.
pub struct Context {
  /// How many errors to queue before flushing.
  max : Int
  queue : Array[Diagnostic]
  source : String?
  /// Labels added to every diagnostic reported here.
  related : Array[Label]
  policy : @warning.Policy
  render : Render?
  /// Error-recovery mode: the input had syntax errors and a best-effort AST
  /// was recovered past them, so name resolution is unreliable -- a construct
  /// dropped at a sync boundary leaves its bindings absent. "Not bound"
  /// diagnostics are then suppressed as likely cascades while genuine errors
  /// in the intact regions still surface.
  mut recovery : Bool
  /// Set once an error has been flushed with `exit_on_error`, so the caller
  /// can turn it into an exit code. MoonBit has no `exit` inside a library, so
  /// the decision is handed back rather than taken here.
  mut failed : Bool
}

///|
pub fn Context::source(self : Context) -> String? {
  self.source
}

///|
pub fn Context::in_recovery(self : Context) -> Bool {
  self.recovery
}

///|
pub fn Context::set_recovery(self : Context, v : Bool) -> Unit {
  self.recovery = v
}

///|
/// Whether an error was reported. The CLI turns this into an exit code.
pub fn Context::failed(self : Context) -> Bool {
  self.failed
}

///|
/// The entries accumulated in a collector, neither cleared nor printed.
pub fn Context::collected(self : Context) -> Array[Diagnostic] {
  self.queue
}

///|
/// A context that buffers reported diagnostics without printing or exiting.
///
/// It renders nothing, so it needs none of a rendering context's parameters.
/// `source` is still worth threading: a lint that inspects the original text
/// runs against this context.
pub fn collector(
  parent? : Context? = None,
  source? : String? = None,
) -> Context {
  let c = {
    max: @int.MAX_VALUE,
    queue: [],
    source,
    related: [],
    policy: @warning.default_policy,
    render: None,
    recovery: false,
    failed: false,
  }
  // A collector checking part of a larger run inherits the parent's recovery
  // mode, so cascade suppression carries into it.
  match parent {
    Some(p) => c.recovery = p.recovery
    None => ()
  }
  c
}

///|
/// Flush the queued errors.
fn Context::flush(self : Context) -> Unit {
  match self.render {
    // A collector renders nothing; read its entries with `collected`.
    None => ()
    Some(r) =>
      if self.queue.length() > 0 {
        for d in self.queue {
          output_error(r.output, r.theme, r.format, self.source, d)
        }
        self.queue.clear()
        if r.exit_on_error {
          (r.output.flush)()
          self.failed = true
        }
      }
  }
}

///|
/// Report a diagnostic.
///
/// `warning` names the warning so the policy can decide its level. It is
/// meaningful for Warning and Suggestion severities and ignored for errors.
pub fn Context::report(
  self : Context,
  loc : @basic.Location,
  severity : Severity,
  message : @message.Message,
  warning? : @warning.Warning? = None,
  universal? : Bool = false,
  hint? : @message.Message? = None,
  edit? : Edit? = None,
  related? : Array[Label] = [],
) -> Unit {
  let all_related = self.related.copy()
  all_related.append(related)
  fn entry(sev : Severity) -> Diagnostic {
    {
      loc,
      severity: sev,
      warning,
      message,
      hint,
      edit,
      related: all_related,
      universal,
    }
  }

  match self.render {
    // A collecting context buffers everything RAW, policy unapplied: the
    // policy belongs to whichever rendering context finally re-reports it.
    None => self.queue.push(entry(severity))
    Some(r) => {
      // Resolve a named warning's level now: hide it, leave it, or promote it
      // to an error. A displayed suggestion stays a Suggestion.
      let resolved : Severity? = match (severity, warning) {
        (Warning, Some(w)) | (Suggestion, Some(w)) =>
          match self.policy.resolve(w) {
            Hidden => None
            Displayed => Some(severity)
            ErrorLevel => Some(Error)
          }
        _ => Some(severity)
      }
      match resolved {
        None => ()
        Some(Error) => {
          self.queue.push(entry(Error))
          if self.queue.length() == self.max {
            self.flush()
          }
        }
        Some(sev) =>
          // Warnings and suggestions print immediately; only errors queue.
          output_error(r.output, r.theme, r.format, self.source, entry(sev))
      }
    }
  }
}

///|
/// Run `f` in a rendering context, flushing its diagnostics afterwards.
///
/// `color` and `palette` are both required: a rendering context must decide up
/// front whether to emit colour, and which source palette to colour embedded
/// AST fragments with, so a caller cannot silently fall back to a default.
pub fn[T] run(
  sink : Sink,
  color : @colors.Flag,
  palette : @colors.Theme,
  source : String?,
  f : (Context) -> T,
  format? : OutputFormat = Human,
  related? : Array[Label] = [],
  exit_on_error? : Bool = true,
  policy? : @warning.Policy = @warning.default_policy,
  is_tty? : Bool = false,
  max? : Int = 1,
) -> (T, Context) {
  let ctx = {
    max,
    queue: [],
    source,
    related,
    policy,
    render: Some({
      theme: get_theme(color~, palette~, is_tty~),
      output: sink,
      format,
      exit_on_error,
    }),
    recovery: false,
    failed: false,
  }
  let res = f(ctx)
  ctx.flush()
  (res, ctx)
}
