# Known Issues

An honest list of Ignid's current rough edges. Most of the bugs that used to be
here have been fixed — see the bottom of this file for what's since been resolved.
What's left is mostly architectural (would need real design work to fix, not a
quick patch) rather than "it just crashes."

## Type system

**`list`/`map` don't track element/value types.** There's no `list<text>` or
`map<text,int>` syntax. In practice:

- A `list` returned from a function call is *always* tagged as if it holds text
  (`fnret_tag()`'s blanket assumption), regardless of what it actually holds — a
  function returning a list of ints would have that list mis-tagged too if you
  index and print an element directly. Route ints through `totext()` explicitly if
  you hit this (it works correctly regardless of the tag, since it doesn't rely on
  the tag — only automatic operators like `+`/`==` do).
- A list built locally via `let list x = {}: push(x, ...):` defaults to being
  read back as `int`. Use `list_new_text()` (see [STDLIB.md](STDLIB.md)) instead
  of `{}` for lists of text you'll index/print directly.
- `map` values are completely untyped — `map_get_text`/`map_get_int`/
  `map_get_float` are separate functions specifically because there's no safe
  generic accessor; always retrieve with the one matching what you stored.

None of this causes a *crash* on its own anymore (the checker now validates
argument types for user-defined functions, so passing the wrong type to something
like `list_has` is now a compile error, not a runtime segfault) — it's a "silently
displays the wrong thing" class of issue if you route around the recommended
patterns above.

**The argument-type checker only covers user-defined functions**, not the ~40
builtins hardcoded in the compiler runtime (`toint`, `sock_send`, etc.) — those
still accept whatever you pass without validation. This is a scope choice, not an
oversight: builtins aren't scanned the way `.ig`-defined functions are.

## `ignidweb`

Single-threaded by design (the memory allocator has no locking — real threads
would race on it), flat JSON only (follows from the `map` limitation above), no
HTTPS, no request timeouts, no path sanitization in `http_serve_file()`. See
[IGNIDWEB.md](IGNIDWEB.md#important-limitations-on-purpose) for the full list and
why each one is the way it is.

[Ignid Webengine](https://github.com/endurasolution/ignid-demo/tree/main/webengine)
covers most of these: request timeouts, strict path sanitization, size limits,
and binary static files. It's still single-threaded and HTTP-only.

## `igcurl`

Plain HTTP only — no TLS, so `https://` URLs are rejected. Response bodies are
handled as NUL-terminated text, so binary downloads (images, archives, PDFs) are
truncated at their first NUL byte; text formats (HTML/JSON/CSS/JS/XML/SVG/plain
text) are fine. One socket per request (`Connection: close` — no keep-alive or
pooling), no request timeout, no compression. See
[IGCURL.md](IGCURL.md#important-limitations-on-purpose) for the full list.

## Compiler internals

**`opt.ig`'s label-deduplication pass is permanently disabled.** It had a genuine
bug that OOM-crashed the optimizer once the input got large enough (first hit
compiling `codegen.ig` itself, around 8000+ IR lines) — the exact mechanism was
never fully isolated despite heavy instrumentation (ruled out: infinite loops,
single huge allocations, string corruption). Since it's a pure optimization pass,
disabling it can't produce incorrect code, only marginally larger compiled
binaries. One visible side effect: `codegen.ig` itself now takes noticeably longer
to recompile as it grows (since it can no longer deduplicate its own labels) —
this only affects rebuilding the compiler, not compiling your programs.

**No float `sqrt`/`pow`/trig functions** — `std.ig` only has integer `sqrt_int`
and `pow`. Only `+ - * / %` are implemented for `float` at the language level.

**`cvtsd2si` uses round-to-nearest-even**, which can occasionally round the "wrong"
way exactly at a `.5` boundary in the 6th decimal place when formatting a float for
display. Cosmetic, not a correctness bug.

## Portability

**The toolchain is not portable out of the box.** `ignidc.ig` hardcodes absolute
paths to NASM, `link.exe`, and the Windows SDK import libraries, matching one
specific machine's install layout. Moving to another Windows machine means editing
those constants (see [GETTING_STARTED.md](GETTING_STARTED.md)) and rebuilding.
There's no installer, no code signing (Windows SmartScreen will flag the compiler
and anything it produces as "unknown publisher"), and Visual Studio Build Tools
(several GB) is a hard dependency for linking.

**Windows x86-64 only.** No Linux, no macOS, no ARM. This is a deliberate scope
choice, not a bug.

## Fixed since being documented here

These used to be listed as known bugs and are now fixed (see the project's
changelog/memory for detail if you're curious about the root causes):

- `list_has`/`list_find` no longer segfault on a mismatched-type list — the
  checker now catches it as a compile-time type error instead.
- `${expr}` string interpolation now correctly handles arbitrary expressions
  (arithmetic, function calls, field access, parens) — it used to only handle a
  bare variable name or one specific `obj.field` shape.
- An early `give`/`stop`/`skip` inside a `try` block no longer leaks internal
  exception-handling state.
- `{key -> val}` map-literal syntax — previously parsed correctly but had no
  code generation at all, causing a silent runtime crash with no compile error.
- `sock_recv` no longer crashes the program when the other side resets the
  connection. `recv()`'s 32-bit error result (-1) was read as a huge positive
  length, and the terminator was written 4GB past the buffer. Any client that
  disconnected abruptly mid-request could take down an Ignid server.
- `ignidweb.ig` no longer hardcodes the developer machine's `d:/Ignid/std.ig`
  path, so `ignidweb` and `demoweb` work on other machines.
