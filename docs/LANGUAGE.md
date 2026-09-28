# Language Reference

## Comments

```
// a line comment — there is no block-comment syntax
```

## Types

| Type | Description |
|---|---|
| `int` | 64-bit signed integer |
| `float` | 64-bit IEEE-754 double |
| `text` | string |
| `bool` | `true`/`false` — represented as an int (0/1) at runtime; `int` and `bool` are mutually compatible |
| `list` | dynamic array, elements can be any single type (see note below on element typing) |
| `map` | key/value store, text keys (see [Maps](#maps)) |
| `any` | can hold any type and be reassigned to a different type later |
| `var` | intended to "lock" to whatever type it's first assigned; currently checked the same as `any` |
| a `rec` name | a record (custom struct) type, see [Records](#records) |
| an `enum` name | an enum type, see [Enums](#enums) |

### A note on list/map element types

`list` and `map` don't carry their element type in the type system (there's no
`list<text>` syntax) — a `list` can hold values of any single runtime type, but the
*compiler* doesn't always know which. This mostly doesn't matter (`push`, `len`,
`list_reverse`, etc. all work regardless), but two things depend on it:

- **Printing/indexing a list built with `let list x = {}: push(x, ...):`** — an
  empty `{}` literal has no way to know what you'll push into it later, so it
  defaults to being read back as `int`. If you're building a list of **text**
  values and plan to index/print elements directly, use `list_new_text()` from
  `std.ig` instead of `{}` — it's correctly tagged. Lists returned from functions
  (`list_reverse()`, `sort_str()`, etc.) are also correctly tagged.
- **`map` values are untyped on `map_set`** — retrieve them with the accessor that
  matches what you stored: `map_get_text`, `map_get_int`, or `map_get_float`. There
  is no generic `map_get` — see [Maps](#maps) for why.

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for the full explanation.

## Variables

```
let int x = 5:            // declare + initialize
let text name = "Ada":
let any a = 42:            // can later be reassigned to a different type
a = "now text":

fix pi = 3.14159:          // constant; type inferred from the initializer, no `let`

x = x + 1:                 // plain assignment (no `let`) — must already be declared
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
— the non-text side is converted automatically:

```
iglog("count: " + totext(5)):     // "count: 5" — totext() is explicit and safest
iglog("count: " + 5):              // also works: + auto-converts a non-text operand
```

`==`/`!=` on two `text` values compare content, not identity. `<`/`>`/`<=`/`>=` are
**not** defined for `text` — use `str_lt`/`str_gt`/`str_eq` from `std.ig` for
lexicographic comparison instead (writing `a < b` on two `text` values silently
compares their internal pointer values, which is never what you want).

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
loop while x < 10 [ x = x + 1: ]                  // while loop

loop i in 0 to 10 [ iglog(i): ]                    // for loop, i = 0..10 inclusive
loop i in 0 to 10 step 2 [ iglog(i): ]              // with a step

loop 3 [ iglog("hi"): ]                              // repeat N times
```

`stop:` breaks out of the innermost loop; `skip:` continues to the next iteration.

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

`give expr:` returns from the function. Functions are not first-class values —
there's no way to pass a function as a parameter or store one in a variable.

## Records

Records are simple structs. There's no method syntax (`obj.method()`) — instead,
write ordinary functions that take the record as their first parameter:

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

Records are **reference types** — passing one to a function and mutating a field
inside that function is visible to the caller, same as passing an object reference
in most other languages. This is what makes the "record + free function" pattern
work as a stand-in for classes/methods.

## Enums

```
enum Color [ Red: Green: Blue: ]

let Color c = Color.Red:
iglog(c == Color.Red):        // enum values compare and behave like ints
```

### match

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
nums{0} = 99:                   // index assignment
```

See the [element-typing note](#a-note-on-listmap-element-types) above for the one
gotcha with `{}`-literal lists of text.

## Maps

```
let map m = {"a" -> 1, "b" -> 2}:   // literal syntax
let map m2 = map_new():              // or build one up
map_set(m2, "x", 10):

map_get_int(m, "a")                    // 1
map_get_text(m2, "missing")            // catchable runtime error — see try/catch
map_has(m, "a")                        // 1 (bool/int)
map_keys(m)                            // list of text keys
len(m)                                  // number of entries
```

`map_set`/`map_get_*` are split by value type (`map_get_text`/`map_get_int`/
`map_get_float`) rather than one generic accessor, because a `map`'s values aren't
tagged at runtime — asking for the wrong type back would silently misinterpret the
bits rather than error. Always retrieve with the accessor matching what you stored.

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
`readfile` on a missing file, and `map_get_*` on a missing key. `lasterror()`
returns the message text of the most recently caught error.

**Known limitation:** an early `give`, `stop`, or `skip` *inside* a `try` block
correctly unwinds and works — this used to leak internal state but is fixed as of
the current version (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md) if you're on an older
build).

## String interpolation

```
let int x = 7: let int y = 3:
iglog("sum: ${x + y}"):        // arbitrary expressions work, including
iglog("point: ${p.x},${p.y}"):  // field access, function calls, parens, etc.
```

Only works inside double-quoted string literals passed directly as `iglog`
arguments or wherever a string literal is used as an expression — `${...}` is
resolved to text at compile time by parsing the interpolated content as a normal
expression.

## Modules

```
// mathlib.ig
fn square(int n) -> int [ give n * n: ]
```

```
// main.ig
use "mathlib.ig":

start [ iglog(square(5)): ]
```

`use` pulls a file's top-level functions/records/enums into the current file. If
two files both `use` the same third file, don't *also* directly `use` that same
file a second time from the entry file — the module-expansion pass doesn't
deduplicate nested `use`s, and you'll get duplicate-symbol errors. `use` a file from
exactly one place in the chain.

## Output

```
iglog("a", "b", 1, 2.5):     // space-separated, trailing newline, to stdout
iglog.err("oops"):             // same, but to stderr, prefixed "[err] "
iglog.warn("careful"):          // same, prefixed "[warn] "
print("no newline"):             // raw text to stdout, no formatting
println("with newline"):          // raw text + newline to stdout
```

## Command-line arguments

```
argc()          // number of arguments passed after the program name
argv(i)          // the i-th argument (0-based) as text
```

See [STDLIB.md](STDLIB.md) for the full list of built-in and standard-library
functions.
