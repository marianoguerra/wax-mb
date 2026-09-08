module fold

fn loop(n, acc):
  if n == 0 | acc | loop(n - 1, acc + n)

export fn run(input):
  loop(input, 0)
