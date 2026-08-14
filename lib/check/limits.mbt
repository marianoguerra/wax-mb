// Memory and table size limits.
//
// Ported from `check_limits` in wax/src/lib-wax/typing.ml, which mirrors the
// wasm validator's own `limits` rule.
//
// The ceiling is not a constant: it is what the ADDRESS TYPE can index, divided
// by the page size. A 32-bit memory of one-byte pages tops out at 2^32 pages; of
// 64KiB pages, at 2^16. So the two immediates that look independent -- the
// address type and the page size -- decide the limit between them.

///|
/// The largest size a memory of this address type and page size can have.
pub fn max_memory_size(
  address_type : @wasm_types.AddressType,
  page_size_log2 : Int?,
) -> UInt64 {
  let p = page_size_log2.unwrap_or(16)
  let (bits, index_max) = match address_type {
    I32 => (32, 0xFFFFFFFFUL)
    I64 => (64, 0xFFFFFFFFFFFFFFFFUL)
  }
  let e = bits - p
  let by_page = if e >= 64 {
    index_max
  } else if e <= 0 {
    0UL
  } else {
    1UL << e
  }
  if index_max <= by_page {
    index_max
  } else {
    by_page
  }
}

///|
/// The largest size a table of this address type can have.
///
/// A table has no page size, so only the address type bounds it.
pub fn max_table_size(address_type : @wasm_types.AddressType) -> UInt64 {
  match address_type {
    I32 => 0xFFFFFFFFUL
    I64 => 0xFFFFFFFFFFFFFFFFUL
  }
}

///|
/// Validate one memory's or table's limits and page size.
///
/// `page_size_log2` is `None` for a table and for a memory that did not write
/// one; a memory that did may only say 1 byte or the default 64KiB, since those
/// are the two the proposal admits.
fn check_limits(
  ctx : @typing_env.ModuleContext,
  location : @basic.Location,
  kind : String,
  address_type : @wasm_types.AddressType,
  limits : (UInt64, UInt64?)?,
  page_size_log2? : Int? = None,
  shared? : Bool = false,
) -> Unit {
  match page_size_log2 {
    None | Some(0) | Some(16) => ()
    Some(_) => invalid_page_size(ctx.diagnostics, location)
  }
  // A shared memory is grown by other threads, so its size has to be bounded:
  // without a maximum there is nothing for them to agree on.
  if shared && !(limits is Some((_, Some(_)))) {
    shared_memory_without_max(ctx.diagnostics, location)
  }
  guard limits is Some((mi, ma)) else { return }
  let max = if kind == "memory" {
    max_memory_size(address_type, page_size_log2)
  } else {
    max_table_size(address_type)
  }
  match ma {
    None =>
      if mi > max {
        limit_too_large(ctx.diagnostics, location, kind, max)
      }
    Some(ma) => {
      if mi > ma {
        limit_mismatch(ctx.diagnostics, location, kind)
      }
      if ma > max {
        limit_too_large(ctx.diagnostics, location, kind, max)
      }
    }
  }
}

///|
/// A `UInt64` as lower-case hex.
///
/// Not `reinterpret_as_int64().to_string(radix=16)`: that renders the top half
/// of the range as a negative number, so a 64-bit memory's ceiling would print
/// as `0x-1`.
pub fn hex_u64(v : UInt64) -> String {
  if v == 0 {
    return "0"
  }
  let digits = "0123456789abcdef"
  let out : Array[Char] = []
  let mut n = v
  while n > 0 {
    out.push(digits.unsafe_get((n % 16UL).to_int()).to_char().unwrap())
    n = n / 16UL
  }
  String::from_array(out.rev())
}
