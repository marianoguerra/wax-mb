module reading

require clock :: std.clock.Wall.v1

record Reading:
  values
  timestamp :: i64

export fn run(input, clock):
  Reading(map(fn(x): x * 2, input), clock.now_ms())
