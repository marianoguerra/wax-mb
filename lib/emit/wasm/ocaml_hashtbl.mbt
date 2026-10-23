// The iteration order of an OCaml `Hashtbl` of strings.
//
// The reference builds two observable orders by folding over a hash table --
// the functions its synthesized declarative element segment lists, and the
// synthesized types it appends to the type section -- so the bytes it writes
// depend on where OCaml's `Hashtbl` puts each key. Neither insertion order nor
// any sort reproduces that; the table has to be simulated: the same hash, the
// same bucket count, the same growth, and the same order within a bucket.

///|
/// OCaml's `Hashtbl.hash` of a string: `caml_hash` with seed 0, whose mixing
/// for a string is MurmurHash3's block and tail steps over its bytes, then its
/// length, then the final avalanche, masked to 30 bits.
fn ocaml_string_hash(s : String) -> Int32 {
  let bytes = @unicode.utf8_bytes(s).map(b => b.reinterpret_as_uint())
  let len = bytes.length()
  fn mix(h : UInt32, d : UInt32) -> UInt32 {
    let mut d = d * 0xcc9e2d51U
    d = (d << 15) | (d >> 17)
    d = d * 0x1b873593U
    let mut h = h ^ d
    h = (h << 13) | (h >> 19)
    h * 5U + 0xe6546b64U
  }

  let mut h : UInt32 = 0
  let mut i = 0
  while i + 4 <= len {
    let w = bytes[i] |
      (bytes[i + 1] << 8) |
      (bytes[i + 2] << 16) |
      (bytes[i + 3] << 24)
    h = mix(h, w)
    i = i + 4
  }
  let rest = len - i
  if rest > 0 {
    let mut w : UInt32 = 0
    if rest >= 3 {
      w = bytes[i + 2] << 16
    }
    if rest >= 2 {
      w = w | (bytes[i + 1] << 8)
    }
    w = w | bytes[i]
    h = mix(h, w)
  }
  h = h ^ len.reinterpret_as_uint()
  h = h ^ (h >> 16)
  h = h * 0x85ebca6bU
  h = h ^ (h >> 13)
  h = h * 0xc2b2ae35U
  h = h ^ (h >> 16)
  (h & 0x3FFFFFFFU).reinterpret_as_int()
}

///|
/// The order `Hashtbl.fold` visits the keys of a table made with
/// `Hashtbl.create 16` and filled by `Hashtbl.replace` with `keys`, in order
/// and without duplicates.
///
/// A new key goes at the HEAD of its bucket; the table doubles once it holds
/// more than twice as many keys as buckets, keeping each bucket's order; and
/// `fold` walks the buckets in index order, each from its head.
fn ocaml_hashtbl_fold_order(keys : Array[String]) -> Array[String] {
  let mut buckets : Array[Array[String]] = Array::makei(16, _ => [])
  let mut size = 0
  for key in keys {
    let n = buckets.length()
    let b = buckets[ocaml_string_hash(key) & (n - 1)]
    b.insert(0, key)
    size = size + 1
    if size > 2 * n {
      let grown : Array[Array[String]] = Array::makei(2 * n, _ => [])
      for old in buckets {
        for k in old {
          grown[ocaml_string_hash(k) & (2 * n - 1)].push(k)
        }
      }
      buckets = grown
    }
  }
  let out = []
  for b in buckets {
    for k in b {
      out.push(k)
    }
  }
  out
}
