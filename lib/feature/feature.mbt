// Optional language features -- the WebAssembly proposals a module may opt in
// to.
//
// Ported from wax/src/lib-utils/feature.ml. A feature is off unless the command
// line (`-X name`) or the module itself (`#![feature = "name"]`) turns it on,
// and a `Set` records which ones a module actually EXERCISED, so a binary can
// carry the declaration forward in its `target_features` section.
//
// The three states matter and are not two: a feature can be off by default, or
// off because someone said `-X name=off`. A module declaring a feature against
// the second is a conflict to report; against the first it is just an opt-in.

///|
/// A proposal this toolchain knows about.
pub(all) enum Feature {
  /// Exact reference types, descriptor structs, and their instructions.
  CustomDescriptors
  /// Grouping a module's imports under one module name in the binary import
  /// section.
  CompactImportSection
} derive(Eq, Compare, Debug)

///|
/// Every known feature, in the order everything reports them.
pub let all : Array[Feature] = [CustomDescriptors, CompactImportSection]

///|
/// The command-line and diagnostic name.
pub fn Feature::name(self : Feature) -> String {
  match self {
    CustomDescriptors => "custom-descriptors"
    CompactImportSection => "compact-import-section"
  }
}

///|
pub fn Feature::description(self : Feature) -> String {
  match self {
    CustomDescriptors =>
      "Custom Descriptors proposal: exact reference types, descriptor structs, and the associated instructions."
    CompactImportSection =>
      "Compact Import Section proposal: group a module's imports under one module name in the binary import section."
  }
}

///|
/// Whether the feature is on when nobody has said otherwise.
///
/// Every proposal here is experimental, so: no.
pub fn Feature::enabled_by_default(self : Feature) -> Bool {
  match self {
    CustomDescriptors => false
    CompactImportSection => false
  }
}

///|
pub fn of_name(s : String) -> Feature? {
  for f in all {
    if f.name() == s {
      return Some(f)
    }
  }
  None
}

///|
/// A resolved configuration: what is enabled, and what has been used.
///
/// One per module, since usage is per-module.
pub struct Set {
  /// The features on, whether by default, by `-X`, or by declaration.
  enabled : @sorted_set.SortedSet[Feature]
  /// The features an `-X name=off` explicitly turned off, which a module
  /// declaring one of them CONFLICTS with -- unlike one merely off by default.
  explicitly_off : @sorted_set.SortedSet[Feature]
  used : @sorted_set.SortedSet[Feature]
}

///|
/// Take the defaults and apply `specs` over them; later entries win.
pub fn configure(specs : Array[(Feature, Bool)]) -> Set {
  let enabled : @sorted_set.SortedSet[Feature] = @sorted_set.SortedSet([])
  let explicitly_off : @sorted_set.SortedSet[Feature] = @sorted_set.SortedSet([])
  for f in all {
    if f.enabled_by_default() {
      enabled.add(f)
    }
  }
  for spec in specs {
    let (f, on) = spec
    if on {
      enabled.add(f)
      explicitly_off.remove(f)
    } else {
      enabled.remove(f)
      explicitly_off.add(f)
    }
  }
  { enabled, explicitly_off, used: @sorted_set.SortedSet([]), }
}

///|
/// The process-wide configuration, installed once from the command line -- the
/// same shape as the warning policy.
let global_specs : Ref[Array[(Feature, Bool)]] = @ref.new([])

///|
pub fn set_config(specs : Array[(Feature, Bool)]) -> Unit {
  global_specs.val = specs
}

///|
/// A fresh set from the installed configuration, nothing used yet.
pub fn default() -> Set {
  configure(global_specs.val)
}

///|
pub fn Set::is_enabled(self : Set, f : Feature) -> Bool {
  self.enabled.contains(f)
}

///|
/// Was this feature turned off explicitly, rather than merely being off?
pub fn Set::explicitly_disabled(self : Set, f : Feature) -> Bool {
  self.explicitly_off.contains(f)
}

///|
/// Turn a feature on because the module declares it.
///
/// Not `declare`: that is a MoonBit keyword.
///
/// Check `explicitly_disabled` first: declaring what the command line turned
/// off is a conflict, not an override.
pub fn Set::declare_feature(self : Set, f : Feature) -> Unit {
  self.enabled.add(f)
}

///|
/// Record that a feature is used -- whether or not it is enabled.
pub fn Set::mark_used(self : Set, f : Feature) -> Unit {
  self.used.add(f)
}

///|
/// What has been used, in `all` order so output is stable.
pub fn Set::used_features(self : Set) -> Array[Feature] {
  all.filter(f => self.used.contains(f))
}

///|
/// Parse a command-line spec: `NAME`, `NAME=on` or `NAME=off`.
pub fn parse_spec(s : String) -> Result[(Feature, Bool), String] {
  let (nm, value) = match s.find("=") {
    None => (s, "on")
    Some(i) => (s[:i].to_owned(), s[i + 1:].to_owned())
  }
  match of_name(nm) {
    None => {
      let known = all.map(f => f.name()).join(", ")
      Err("Unknown feature '\{nm}'. Known features: \{known}.")
    }
    Some(f) =>
      match value {
        "on" | "true" | "yes" => Ok((f, true))
        "off" | "false" | "no" => Ok((f, false))
        _ =>
          Err(
            "Malformed feature spec '\{s}'; expected NAME, NAME=on, or NAME=off.",
          )
      }
  }
}
