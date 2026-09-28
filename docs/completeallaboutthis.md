# Ignid — Complete Reference

Everything about the Ignid programming language in one place: full syntax, every
builtin and standard-library function, and how the pieces fit together. This is
the all-in-one version of [LANGUAGE.md](LANGUAGE.md) + [STDLIB.md](STDLIB.md) plus
the newer features (streaming I/O, encapsulation, `printout`, coroutines) in a
single document.

## Table of contents

1. [What Ignid is](#what-ignid-is)
2. [Installing / running programs](#installing--running-programs)
3. [Comments](#comments)
4. [Types](#types)
5. [Variables](#variables)
6. [Operators](#operators)
7. [Control flow](#control-flow)
8. [Functions](#functions)
9. [Records (OOP)](#records-oop)
10. [Encapsulation (`private` fields)](#encapsulation-private-fields)
11. [Enums + match](#enums--match)
12. [Lists](#lists)
13. [Maps](#maps)
14. [try/catch](#trycatch)
15. [String interpolation](#string-interpolation)
16. [Modules (`use`)](#modules-use)
17. [Output](#output)
18. [Streaming file I/O](#streaming-file-io)
19. [Concurrency (coroutines)](#concurrency-coroutines)
20. [Command-line arguments](#command-line-arguments)
21. [Complete builtin function reference](#complete-builtin-function-reference)
22. [Complete `std.ig` reference](#complete-stdig-reference)
23. [Networking (`ignidweb`)](#networking-ignidweb)
24. [Known limitations](#known-limitations)
25. [License](#license)

---

## What Ignid is

Ignid is a self-hosted, statically-typed programming language that compiles
directly to native 64-bit Windows executables (`.exe`, PE32+, `x86-64`). The
entire toolchain — type checker, IR generator, optimizer, and x86-64 code
generator — is itself written in Ignid and compiled by itself (a self-hosting
bootstrap). Programs are compiled via NASM (assembler) and the MSVC linker
(`link.exe`); the compiler auto-detects both if Visual Studio Build Tools is
installed.

Windows x86-64 only — no Linux, no macOS, no ARM. This is a deliberate scope
choice.

## Installing / running programs

Two command-line tools:

```
ignidc          reads a source path from stdin, compiles it, does not run it
ignid <file.ig> [args...]     compiles AND runs file.ig in one step, passing
                                 args... through to the compiled program
ignid --version                prints the compiler version
```

```
> ignid hello.ig
Hello, Ignid!
```

`ignid` only shows your program's own output — no compiler noise — and builds
entirely out of a temp folder, so nothing is left behind next to your source.
`ignidc` is the opposite: it shows full stage-by-stage progress and leaves the
`.exe` where you can find it, since that's the point of using it directly.

Inside a running program, `argc()`/`argv(i)` read back whatever was passed
after the filename (see [Command-line arguments](#command-line-arguments)).

### Interactive REPL

Run `ignid` with no arguments (like running `node` with no arguments) to get
an interactive session:

```
> ignid
Ignid v1.0.0 — interactive REPL
Type ".help" for more information.

ignid> let int x = 5:
ignid> x + 3
=> 8
ignid> .exit
Goodbye!
```

A line ending in `:` runs as a normal statement (declarations, `iglog(...)`,
`when`/`loop`, etc.) and silently becomes part of the session's state. A line
with **no** trailing `:` is treated as an expression — its value is evaluated
and printed, but it's never replayed on later turns. Variables set in one line
are available in the next, since the whole session is really one growing
program recompiled fresh each turn (Ignid has no interpreter — this is a
compiled language). Commands: `.help`, `.clear` (forget all session state),
`.exit`. Note: if you call `iglog`/`print` yourself inside a `:`-terminated
statement, that output reruns on every subsequent turn along with the rest of
the session, same as a real program's side effect would — prefer the no-colon
expression form for one-off "show me this value" queries.

### Giving your compiled program a custom icon

Drop a `.ico` file next to your source with the same base name — e.g.
`myapp.ico` next to `myapp.ig` — and `ignidc`/`ignid` will automatically embed
it as `myapp.exe`'s icon (via the Windows resource compiler, `rc.exe`, which
ships with Visual Studio Build Tools). No source changes or flags needed; if
no matching `.ico` is present, or the resource compiler isn't installed, the
program just gets Windows' default executable icon as before — this never
fails a build either way.

See [GETTING_STARTED.md](GETTING_STARTED.md) for first-time setup and
[BUILDING.md](BUILDING.md) if you're rebuilding the compiler itself from source.

## Comments

```
// a line comment — there is no block-comment syntax
```

## Types

| Type | Description |
|---|---|
| `int` | 64-bit signed integer |
| `float` | 64-bit IEEE-754 double (SSE2, real floating point — not fixed-point) |
| `text` | string |
| `bool` | `true`/`false` — represented as an int (0/1) at runtime; `int` and `bool` are mutually compatible |
| `list` | dynamic array, elements can be any single type |
| `map` | key/value store, text keys |
| `any` | can hold any type and be reassigned to a different type later |
| `var` | intended to "lock" to whatever type it's first assigned; currently checked the same as `any` |
| a `rec` name | a record (custom struct) type — see [Records](#records-oop) |
| an `enum` name | an enum type — see [Enums](#enums--match) |

### list/map element typing caveat

`list` and `map` don't carry their element type in the type system (there's no
`list<text>` syntax):

- A `list` built with `let list x = {}: push(x, ...):` defaults to being read
  back as `int`. For a list of **text** you'll index/print directly, use
  `list_new_text()` instead of `{}` — it's correctly tagged. Lists *returned
  from functions* (`list_reverse()`, `sort_str()`, `split()`, etc.) are already
  correctly tagged.
- `map` values are untyped on `map_set` — retrieve with the accessor matching
  what you stored: `map_get_text`, `map_get_int`, or `map_get_float`. There is
  no generic `map_get`.

## Variables

```
let int x = 5:              // declare + initialize
let text name = "Ada":
let any a = 42:               // can later be reassigned to a different type
a = "now text":

fix pi = 3.14159:             // constant; type inferred from initializer, no `let`

x = x + 1:                    // plain assignment (no `let`) — must already be declared
```

## Operators

```
+ - * /  %              arithmetic (% is modulo; also works on float as true fmod)
== != < > <= >=          comparison
and or not               logical (short-circuit)
-x                        unary minus
```

Precedence, loosest to tightest:
`or` < `and` < `not` < `== !=` < `> < >= <=` < `+ -` < `* / %` < unary `-`

`+` on two `text` values (or a `text` and any other printable type) concatenates
— the non-text side is auto-converted:

```
iglog("count: " + totext(5)):     // "count: 5" — totext() is explicit and safest
iglog("count: " + 5):              // also works: + auto-converts a non-text operand
```

`==`/`!=` on two `text` values compare content, not identity. `<`/`>`/`<=`/`>=`
are **not** defined for `text` — use `str_lt`/`str_gt`/`str_eq` instead
(writing `a < b` on two `text` values silently compares pointer values, never
what you want).

## Control flow

### if / elif / else

```
when x > 10 [ iglog("big"): ]
or   x > 5  [ iglog("medium"): ]
else        [ iglog("small"): ]
```

`or` branches and the final `else` are both optional.

### Loops

```
loop while x < 10 [ x = x + 1: ]                    // while loop

loop i in 0 to 10 [ iglog(i): ]                       // for loop, i = 0..10 inclusive
loop i in 0 to 10 step 2 [ iglog(i): ]                 // with a step

loop 3 [ iglog("hi"): ]                                 // repeat N times
```

`stop:` breaks out of the innermost loop; `skip:` continues to the next
iteration. Both correctly unwind out of any enclosing `try` block they escape
(see [try/catch](#trycatch)).

## Functions

```
fn add(int a, int b) -> int [
    give a + b:
]

fn greet(text name) -> int [    // return type defaults to int if omitted
    iglog("hi " + name):
    give 0:
]
```

`give expr:` returns from the function. Functions are **not first-class
values** — there's no way to pass a function as a parameter or store one in a
variable. (This is why `spawn` below takes a function *name*, not a value.)

## Records (OOP)

Records are simple structs — Ignid's stand-in for classes. There's no method
syntax (`obj.method()`); instead write ordinary functions that take the record
as their first parameter:

```
rec Point [ int x: int y: ]

fn make_point(int x, int y) -> Point [ give Point(x, y): ]

fn distance_sq(Point a, Point b) -> int [
    let int dx = a.x - b.x: let int dy = a.y - b.y:
    give dx * dx + dy * dy:
]

start [
    let Point p = Point(3, 4):
    iglog(p.x, p.y):
    p.x = 10:                     // fields are mutable
]
```

Records are **reference types** — passing one to a function and mutating a
field inside that function is visible to the caller, the same as passing an
object reference in most other languages. This "record + free function"
pattern is what stands in for classes/methods; see
[demos/06_class_style.ig](../demos/06_class_style.ig) for a worked example
(bank-account style, with a "constructor" function and "method" functions that
all take the record as their first argument).

## Encapsulation (`private` fields)

A record field can be marked `private`:

```
// account.ig
rec Account [
    private int balance:
    text owner:
]

fn deposit(Account a, int amount) -> int [
    a.balance = a.balance + amount:    // OK — this function is in the same file as `rec Account`
    give 0:
]
```

```
// main.ig
use "account.ig":
start [
    let Account a = Account(0, "Alice"):
    deposit(a, 100):        // fine — deposit() is in account.ig
    iglog(a.balance):        // COMPILE ERROR — main.ig is a different file
]
```

Privacy is **file-scoped**, not instance- or type-scoped: a `private` field can
only be read or written by functions defined in the *same source file* as the
`rec` declaration. This is checked at compile time (a type error, not a
runtime failure) and is enforced on both reads and writes, since assignment
reuses the same field-access parsing path.

## Enums + match

```
enum Color [ Red: Green: Blue: ]

let Color c = Color.Red:
iglog(c == Color.Red):        // enum values compare and behave like ints
```

```
fn color_name(Color c) -> text [
    match c [
        Color.Red   [ give "red": ]
        Color.Green [ give "green": ]
        else        [ give "blue": ]
    ]
]
```

## Lists

```
let list nums = {1, 2, 3}:
let list empty = {}:
push(nums, 4):
iglog(len(nums), nums{0}):     // {i} indexes a list (or a text string, by character)
nums{0} = 99:                    // index assignment
```

See the [element-typing caveat](#listmap-element-typing-caveat) above for the
`{}`-literal-of-text gotcha.

## Maps

```
let map m = {"a" -> 1, "b" -> 2}:    // literal syntax
let map m2 = map_new():               // or build one up
map_set(m2, "x", 10):

map_get_int(m, "a")                     // 1
map_get_text(m2, "missing")             // catchable runtime error — see try/catch
map_has(m, "a")                          // 1 (bool/int)
map_keys(m)                               // list of text keys
len(m)                                    // number of entries
```

`map_set`/`map_get_*` are split by value type rather than one generic
accessor, because a `map`'s values aren't tagged at runtime — asking for the
wrong type back would silently misinterpret the bits rather than error.
Always retrieve with the accessor matching what you stored (`map_get_text`,
`map_get_int`, or `map_get_float`).

## try/catch

```
try [
    let int x = toint("not a number"):    // triggers a runtime error
] catch [
    iglog("caught:", lasterror()):
]
```

Catchable runtime errors: division by zero, list/text index out of bounds,
`pop()` on an empty list, `toint`/`tofloat` on unparseable text, out of memory,
`readfile`/`file_open` on a missing file, and `map_get_*` on a missing key.
`lasterror()` returns the message text of the most recently caught error.
`catch` does **not** bind a variable — there is no `catch err [...]` form;
always retrieve the message via `lasterror()` inside the catch block.

An early `give`, `stop`, or `skip` *inside* a `try` block correctly unwinds the
internal exception-handling state — this used to leak but is fixed.

Under a running coroutine (see below), each coroutine's try/catch state is
fully isolated from every other coroutine's, even when one yields mid-`try`
while another independently throws/catches.

## String interpolation

```
let int x = 7: let int y = 3:
iglog("sum: ${x + y}"):         // arbitrary expressions work, including
iglog("point: ${p.x},${p.y}"):   // field access, function calls, parens, etc.
```

`${...}` is resolved to text at compile time by re-lexing and parsing the
interpolated content as a normal expression — only works inside double-quoted
string literals used directly as an expression (e.g. an `iglog(...)` argument).

## Modules (`use`)

```
// mathlib.ig
fn square(int n) -> int [ give n * n: ]
```

```
// main.ig
use "mathlib.ig":

start [ iglog(square(5)): ]
```

`use` splices a file's content in-place at the `use` directive's position,
pulling its top-level functions/records/enums into the current file. If two
files both `use` the same third file, don't *also* directly `use` that same
file a second time from the entry file — the module-expansion pass doesn't
deduplicate nested `use`s, and you'll get duplicate-symbol errors. `use` a file
from exactly one place in the chain.

**A file with its own `start` block, when `use`d by another file that also has
a `start` block, has its `start` block silently discarded** — only one
`start` "wins" as the actual entry point (the outer file's). Top-level
statements (outside any `fn`/`start`) don't have this problem; they run
unconditionally as part of program init regardless of which file's `start`
ends up as the entry point. This matters if you're writing a file meant to be
both standalone-runnable *and* used as a library — put any startup logic that
must always run in top-level statements, not inside that file's own `start`.

## Output

```
iglog("a", "b", 1, 2.5):     // space-separated, trailing newline, to stdout
iglog.err("oops"):              // same, but to stderr, prefixed "[err] "
iglog.warn("careful"):           // same, prefixed "[warn] "
printout("a", "b", 1, 2.5):      // same formatting as iglog, but NO trailing newline
print("no newline"):              // raw text to stdout, no formatting/spacing
println("with newline"):           // raw text + newline to stdout
```

`iglog`/`printout` both accept a mix of `text`, `int`, `float`, and `list`
arguments, space-separated, with lists rendered as `{a, b, c}`. `printout` is
the one to reach for when you want that same multi-argument formatting but
need to keep building the same output line (e.g. a progress indicator).

## Streaming file I/O

For reading a file incrementally instead of loading it all into memory at once
(mirrors the socket read pattern):

```
let int h = file_open("big.txt"):
loop while file_eof(h) == 0 [
    let text chunk = file_read_chunk(h, 4096):    // up to 4096 bytes; "" at EOF
    printout(chunk):
]
file_close(h):
```

`file_open` raises a catchable error (same `try`/`catch` mechanism, message
"cannot open file") if the path doesn't exist. Local files only — no network
streaming beyond the raw socket builtins.

For "just give me the whole file" cases, plain `readfile(path)` remains
simpler and is unaffected by any of this.

## Concurrency (coroutines)

Ignid's concurrency model is **cooperative, single-threaded coroutines** — no
OS threads, no locking, no heap-corruption risk from concurrent access. A
coroutine is a zero-argument function that voluntarily yields control:

```
fn worker_a() -> int [
    iglog("A: step 1"): yield:
    iglog("A: step 2"): yield:
    iglog("A: step 3"):
    give 0:
]

fn worker_b() -> int [
    iglog("B: step 1"): yield:
    iglog("B: step 2"):
    give 0:
]

start [
    spawn worker_a():     // registers the coroutine — does NOT run it yet
    spawn worker_b():
    run_coroutines():       // runs the scheduler until every spawned coroutine finishes
    iglog("all done"):
]
```

- `spawn fname():` — `fname` must be a declared, zero-argument function.
  Registration is lazy; nothing runs until `run_coroutines()` is called.
- `yield:` — suspends the current coroutine and returns control to the
  scheduler; resumes right after this point next time it's this coroutine's
  turn.
- `run_coroutines()` — runs a LIFO scheduling loop, resuming each ready
  coroutine in turn, until all spawned coroutines have completed. Control only
  returns to the code after `run_coroutines()` once every coroutine is done.

Implementation note (only matters if you're curious, not for using it):
coroutines are real stackful coroutines using manual `ret`-based context
switching, each with its own heap-allocated stack — not generators or
async/await sugar over a state machine. `try`/`catch` state is fully
isolated per-coroutine, so one coroutine's exception handling can't corrupt
another's even when they interleave mid-`try`.

## Command-line arguments

```
argc()          // number of arguments passed after the program name
argv(i)          // the i-th argument (0-based) as text
```

## Complete builtin function reference

Builtins are implemented directly in the compiler runtime — always available,
no `use` needed.

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
| `abs(x)` | `int\|float -> same` | float-aware |
| `min(a, b)` / `max(a, b)` | `int\|float, int\|float -> same` | mixed int/float args are promoted; float-aware |

### I/O

| Function | Signature | Notes |
|---|---|---|
| `ask(prompt)` | `text -> text` | prints `prompt`, reads one line from stdin |
| `print(s)` / `println(s)` | `text -> int` | raw output, no auto-formatting |
| `printout(...)` | `any... -> int` | `iglog`-style multi-arg formatting, no trailing newline |
| `readfile(path)` | `text -> text` | whole file contents; catchable error if missing |
| `writefile(path, content)` | `text, text -> int` | |
| `file_open(path)` | `text -> int` | streaming read handle; catchable error if missing |
| `file_read_chunk(handle, n)` | `int, int -> text` | up to `n` bytes; `""` at EOF |
| `file_eof(handle)` | `int -> int` | 1 if the read position is at/past EOF |
| `file_close(handle)` | `int -> int` | |
| `clock()` | `-> int` | milliseconds, monotonic-ish tick count |
| `system(cmd)` | `text -> int` | run a shell command (`cmd.exe /c`), returns its exit code |
| `quit(code)` | `int -> (never returns)` | exit the process immediately |
| `argc()` / `argv(i)` | `-> int` / `int -> text` | command-line arguments |
| `lasterror()` | `-> text` | message of the most recently caught error |
| `getenv(name)` | `text -> text` | environment variable value, or `""` if unset |
| `exedir()` | `-> text` | directory containing the currently running `.exe` |

### Sockets (raw TCP — see [IGNIDWEB.md](IGNIDWEB.md) for the higher-level wrapper)

| Function | Signature |
|---|---|
| `sock_listen(port)` | `int -> int` (listener handle) |
| `sock_accept(listener)` | `int -> int` (connection handle) |
| `sock_recv(sock)` | `int -> text` (one read, up to ~4KB) |
| `sock_send(sock, data)` | `int, text -> int` |
| `sock_close(sock)` | `int -> int` |

### Maps

| Function | Signature | Notes |
|---|---|---|
| `map_new()` | `-> map` | |
| `map_set(m, key, val)` | `map, text, any -> map` | |
| `map_get_text(m, key)` / `map_get_int(m, key)` / `map_get_float(m, key)` | `map, text -> text\|int\|float` | catchable error if key missing |
| `map_has(m, key)` | `map, text -> int` | |
| `map_keys(m)` | `map -> list` | list of text keys |

### Concurrency

| Function | Signature | Notes |
|---|---|---|
| `run_coroutines()` | `-> int` | runs the scheduler until every `spawn`ed coroutine finishes |

(`spawn fname():` and `yield:` are language keywords/statements, not function
calls — see [Concurrency](#concurrency-coroutines).)

## Complete `std.ig` reference

Ordinary Ignid functions, not builtins — add
`use "d:/Ignid/std.ig":` (adjust the path to wherever `std.ig` lives relative
to your file) to use them.

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
| `str_lt(a, b)` / `str_gt(a, b)` / `str_eq(a, b)` | `text, text -> int` | lexicographic comparison — use instead of `<`/`>` on text |

### Lists

| Function | Signature | Notes |
|---|---|---|
| `list_new_text()` | `-> list` | correctly-tagged empty list for text elements — prefer over `{}` when you'll index/print elements directly |
| `list_has(l, val)` / `list_find(l, val)` | `list, text -> int` | **text-only** — do not call on an int list |
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

No float versions of `sqrt`/`pow`/trig exist yet — only the int math above and
the raw `+ - * / %` operators on `float`.

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

## Networking (`ignidweb`)

A small Flask-like HTTP library (`ignidweb.ig`) built on the raw socket
builtins: routing (via `when`/`or`, since there are no first-class functions
for decorators), query params, headers, POST bodies, `:id`-style path
segments, static file serving, keep-alive connections, and flat JSON
(`json_str`/`json_num`/`json_object`/`json_decode`). Plain HTTP only — no
WebSocket, no HTTPS. Single-threaded by design (the heap allocator has no
locking). See [IGNIDWEB.md](IGNIDWEB.md) for the full reference and
[demos/demoweb.ig](../demos/demoweb.ig) for a working example.

## Known limitations

Full honest list, including root causes and why each is the way it is, lives
in [KNOWN_ISSUES.md](KNOWN_ISSUES.md). Highlights:

- `list`/`map` don't track element/value types (see the
  [typing caveat](#listmap-element-typing-caveat) above).
- `opt.ig`'s label-deduplication optimizer pass is permanently disabled (a
  genuine OOM bug, never fully isolated) — correctness-safe, just produces
  marginally larger binaries.
- No float `sqrt`/`pow`/trig — only `+ - * / %` at the language level.
- Windows x86-64 only.
- The compiler auto-detects NASM/MSVC/Windows SDK via the installer, but the
  binaries themselves aren't code-signed — Windows SmartScreen will flag them
  and anything compiled with them as "unknown publisher."

## License

Ignid is open source under the [Apache License 2.0](../LICENSE) — free to
use, modify, and redistribute, including for commercial projects. Programs
*you* write and compile with Ignid are entirely yours, with no obligation
back to this license. The "Ignid" name and logo are trademarks, kept
separate from the code license — see [TRADEMARK.md](../TRADEMARK.md) if
you're forking or redistributing. Official site: https://ignid.org/
