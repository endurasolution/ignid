# Standard Library Reference

Two layers: **builtins** (implemented directly in the compiler runtime, always
available, no `use` needed) and **`std.ig`** (ordinary Ignid functions — add
`use "d:/Ignid/std.ig":` to use them, adjusting the path to wherever `std.ig` lives
relative to your file).

## Builtins

### Type conversion

| Function | Signature | Notes |
|---|---|---|
| `totext(x)` | `int\|float -> text` | |
| `toint(s)` | `text -> int` | errors (catchable) on unparseable input |
| `tofloat(s)` | `text -> float` | errors (catchable) on unparseable input |
| `int_to_float(n)` | `int -> float` | |
| `float_to_int(f)` | `float -> int` | truncates, does not round |

### Text and lists

| Function | Signature | Notes |
|---|---|---|
| `len(x)` | `text\|list\|map -> int` | length / element count |
| `sub(s, start, end)` | `text, int, int -> text` | substring, `[start, end)` |
| `ord(ch)` | `text -> int` | character code of a 1-char text |
| `chr(n)` | `int -> text` | 1-char text from a character code |
| `push(l, val)` | `list, any -> list` | append, returns the list |
| `pop(l)` | `list -> any` | remove and return the last element |

### Math

| Function | Signature | Notes |
|---|---|---|
| `abs(x)` | `int\|float -> same` | |
| `min(a, b)` / `max(a, b)` | `int\|float, int\|float -> same` | mixed int/float args are promoted |

### I/O

| Function | Signature | Notes |
|---|---|---|
| `ask(prompt)` | `text -> text` | prints `prompt`, reads one line from stdin |
| `print(s)` / `println(s)` | `text -> int` | raw output, no auto-formatting |
| `readfile(path)` | `text -> text` | whole file contents; catchable error if missing |
| `writefile(path, content)` | `text, text -> int` | |
| `clock()` | `-> int` | milliseconds, monotonic-ish tick count |
| `system(cmd)` | `text -> int` | run a shell command, returns its exit code |
| `quit(code)` | `int -> (never returns)` | exit the process immediately |
| `argc()` / `argv(i)` | `-> int` / `int -> text` | command-line arguments |
| `lasterror()` | `-> text` | message of the most recently caught error |

### Sockets (raw TCP — see [IGNIDWEB.md](IGNIDWEB.md) for the server-side wrapper and [IGCURL.md](IGCURL.md) for the HTTP client)

| Function | Signature |
|---|---|
| `sock_listen(port)` | `int -> int` (listener handle) |
| `sock_accept(listener)` | `int -> int` (connection handle) |
| `sock_connect(host, port)` | `text, int -> int` (connection handle, or `0` on failure) — client side; resolves `host` via DNS |
| `sock_recv(sock)` | `int -> text` (one read, up to ~4KB) |
| `sock_recv_all(sock)` | `int -> text` (reads until the peer closes; grows as needed) |
| `sock_send(sock, data)` | `int, text -> int` |
| `sock_close(sock)` | `int -> int` |

`sock_recv` / `sock_recv_all` return NUL-terminated text, so a stream carrying an
embedded NUL byte (binary data) is observed truncated at the first one.

### Maps

| Function | Signature | Notes |
|---|---|---|
| `map_new()` | `-> map` | |
| `map_set(m, key, val)` | `map, text, any -> map` | |
| `map_get_text(m, key)` / `map_get_int(m, key)` / `map_get_float(m, key)` | `map, text -> text\|int\|float` | catchable error if key missing; use the accessor matching what you stored |
| `map_has(m, key)` | `map, text -> int` | |
| `map_keys(m)` | `map -> list` | list of text keys |

## `std.ig`

### Strings — character classification

`is_space(ch)`, `is_upper_c(ch)`, `is_lower_c(ch)`, `is_alpha_c(ch)`,
`is_digit_c(ch)`, `is_alnum_c(ch)` — all `text -> int`, operate on a single
character.

### Strings — general

| Function | Signature | Notes |
|---|---|---|
| `ltrim(s)` / `rtrim(s)` / `trim(s)` | `text -> text` | strip whitespace |
| `upper(s)` / `lower(s)` | `text -> text` | |
| `find(s, needle)` | `text, text -> int` | index of first match, or -1 |
| `starts_with(s, prefix)` / `ends_with(s, suffix)` | `text, text -> int` | |
| `contains_str(s, needle)` | `text, text -> int` | |
| `replace(s, old, new)` | `text, text, text -> text` | replaces all occurrences |
| `split(s, sep)` | `text, text -> list` | `sep` can be multi-character |
| `join(words, sep)` | `list, text -> text` | inverse of `split` |
| `repeat(s, n)` | `text, int -> text` | |
| `str_count(s, ch)` | `text, text -> int` | count occurrences of a substring |
| `reverse_str(s)` | `text -> text` | |
| `pad_left(s, n, ch)` / `pad_right(s, n, ch)` | `text, int, text -> text` | pad to width `n` |
| `str_lt(a, b)` / `str_gt(a, b)` / `str_eq(a, b)` | `text, text -> int` | lexicographic comparison — use these instead of `<`/`>` on text |

### Lists

| Function | Signature | Notes |
|---|---|---|
| `list_new_text()` | `-> list` | correctly-tagged empty list for text elements — prefer this over `{}` when you'll index/print elements directly |
| `list_has(l, val)` / `list_find(l, val)` | `list, text -> int` | **text-only** — do not call on an int list (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)) |
| `list_reverse(l)` | `list -> list` | |
| `list_slice(l, start, end)` | `list, int, int -> list` | `[start, end)` |
| `list_remove(l, idx)` | `list, int -> list` | new list with the element at `idx` removed |
| `list_concat(a, b)` | `list, list -> list` | |
| `sort_str(l)` | `list -> list` | for lists of text |
| `sort_int(l)` | `list -> list` | for lists of int |

### Math

| Function | Signature | Notes |
|---|---|---|
| `pow(base, exp)` | `int, int -> int` | |
| `sqrt_int(n)` | `int -> int` | integer (floor) square root |
| `gcd(a, b)` / `lcm(a, b)` | `int, int -> int` | |
| `is_prime(n)` | `int -> int` | |
| `clamp(v, lo, hi)` | `int, int, int -> int` | |
| `sign(x)` | `int -> int` | -1, 0, or 1 |

No float versions of `sqrt`/`pow`/trig exist yet — only the int math above.

### Random

Simple seeded LCG, not cryptographically secure.

| Function | Signature |
|---|---|
| `rand_seed(s)` | `int -> int` |
| `rand_next()` | `-> int` |
| `rand_int(lo, hi)` | `int, int -> int` |
| `rand_bool()` | `-> int` |
| `rand_float_pct()` | `-> int` (0-100) |

### File I/O

| Function | Signature |
|---|---|
| `read_lines(path)` | `text -> list` |
| `write_lines(lines, path)` | `list, text -> int` |
