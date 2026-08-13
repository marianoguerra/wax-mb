///|
test "a feature is off unless something turns it on" {
  let s = @feature.configure([])
  assert_false(s.is_enabled(CustomDescriptors))
  assert_false(s.explicitly_disabled(CustomDescriptors))
}

///|
test "off by default and explicitly off are different states" {
  // A module declaring a feature the command line turned off is a conflict; one
  // declaring a feature that is merely off is just opting in. Nothing can tell
  // those apart without this distinction.
  let s = @feature.configure([(CustomDescriptors, false)])
  assert_false(s.is_enabled(CustomDescriptors))
  assert_true(s.explicitly_disabled(CustomDescriptors))
}

///|
test "later specs win" {
  let s = @feature.configure([
    (@feature.Feature::CustomDescriptors, true),
    (CustomDescriptors, false),
  ])
  assert_false(s.is_enabled(CustomDescriptors))
  assert_true(s.explicitly_disabled(CustomDescriptors))
  let t = @feature.configure([
    (@feature.Feature::CustomDescriptors, false),
    (CustomDescriptors, true),
  ])
  assert_true(t.is_enabled(CustomDescriptors))
  assert_false(t.explicitly_disabled(CustomDescriptors))
}

///|
test "a module can declare a feature the command line did not" {
  let s = @feature.configure([])
  s.declare_feature(CompactImportSection)
  assert_true(s.is_enabled(CompactImportSection))
  assert_false(s.is_enabled(CustomDescriptors))
}

///|
test "usage is recorded in a stable order, and only once" {
  let s = @feature.configure([])
  s.mark_used(CompactImportSection)
  s.mark_used(CustomDescriptors)
  s.mark_used(CompactImportSection)
  // `all` order, not the order they were marked.
  inspect(
    s.used_features().map(f => f.name()).join(" "),
    content="custom-descriptors compact-import-section",
  )
}

///|
test "usage does not imply enablement" {
  // A module can use what it was not allowed to use -- that is the diagnostic,
  // and recording it is how the binary keeps the declaration.
  let s = @feature.configure([])
  s.mark_used(CustomDescriptors)
  assert_false(s.is_enabled(CustomDescriptors))
  inspect(s.used_features().length(), content="1")
}

///|
test "spec parsing takes the three spellings of each answer" {
  let ok = [
    "custom-descriptors", "custom-descriptors=on", "custom-descriptors=true", "custom-descriptors=yes",
  ]
  for spec in ok {
    inspect(
      @feature.parse_spec(spec) is Ok((CustomDescriptors, true)),
      content="true",
    )
  }
  for
    spec in [
      "custom-descriptors=off", "custom-descriptors=false", "custom-descriptors=no",
    ] {
    inspect(
      @feature.parse_spec(spec) is Ok((CustomDescriptors, false)),
      content="true",
    )
  }
}

///|
test "an unknown feature lists the known ones" {
  guard! @feature.parse_spec("relaxed-simd") is Err(msg)
  inspect(
    msg,
    content="Unknown feature 'relaxed-simd'. Known features: custom-descriptors, compact-import-section.",
  )
  guard! @feature.parse_spec("custom-descriptors=maybe") is Err(msg2)
  inspect(
    msg2,
    content="Malformed feature spec 'custom-descriptors=maybe'; expected NAME, NAME=on, or NAME=off.",
  )
}
