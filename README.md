# Ignid

![Ignid](https://ignid.org/logo.png)

Official site: [ignid.org](https://ignid.org/)

Ignid is a small, statically-typed programming language with its own self-hosted
compiler — the compiler itself is written in Ignid, and compiles Ignid source directly
to native x86-64 Windows executables (no interpreter, no VM, no external runtime to
ship). It's free to download and use; see [LICENSE](LICENSE) for terms.

```
// hello.ig
start [
    let text name = "World":
    iglog("Hello, " + name + "!"):
]
```

```
> ignid hello.ig
Hello, World!
```

## Why Ignid

- **Native executables.** `ignid demo.ig` compiles straight to `demo.exe`. Nothing
  else needs to be installed to *run* a compiled program.
- **Self-hosted.** Every stage of the compiler — lexer, parser, type checker, IR
  generator, optimizer, code generator — is written in Ignid itself.
- **Batteries included.** Records, enums, pattern matching, try/catch, a `map` type,
  real floats, and a small standard library covering strings/lists/math/random/files.
- **Web servers in Ignid.** [Ignid Webengine](https://github.com/endurasolution/ignid-demo/tree/main/webengine)
  is a hardened, Flask-style framework: routes, HTML templates, static files of any
  type, a debug mode, and a 67-case attack test suite. [`ignidweb`](docs/IGNIDWEB.md)
  is the minimal original. Both serve HTTP straight from a compiled `.exe`, with no
  external server needed. [`igcurl`](docs/IGCURL.md) fetches and downloads over
  HTTP like a tiny `curl`.

## Installing

Ignid currently targets **Windows x86-64 only** and, to compile, needs:

- [NASM](https://www.nasm.us/) (the assembler)
- Microsoft Visual Studio Build Tools or Visual Studio, with the **Desktop
  development with C++** workload (for `link.exe` and the Windows SDK import
  libraries `kernel32.Lib`/`WS2_32.Lib`)

`ignidc.ig` (the compiler driver) hardcodes the paths to these tools near the top of
the file — if your NASM or Visual Studio install lives somewhere other than the
default, edit `IG_NASM`/`IG_LINK`/`IG_MSVCRT`/`IG_KERNEL`/`IG_WS2` in `ignidc.ig`
(and `demos/ignid.bat` if present) to match, then see
[docs/BUILDING.md](docs/BUILDING.md) for how to rebuild the toolchain after editing
it.

Once built, add the folder containing `ignid.exe` to your `PATH` so `ignid file.ig`
works from any directory. See [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) for
a full walkthrough.

## Documentation

| Doc | What's in it |
|---|---|
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | Install, compile your first program, the `ignid`/`ignidc` CLI |
| [docs/LANGUAGE.md](docs/LANGUAGE.md) | Full language reference — types, control flow, functions, records, enums, try/catch, modules |
| [docs/STDLIB.md](docs/STDLIB.md) | Every built-in function and standard-library function, by category |
| [Ignid Webengine](https://github.com/endurasolution/ignid-demo/tree/main/webengine) | Hardened web framework: templates, static files, debug mode, security |
| [docs/IGNIDWEB.md](docs/IGNIDWEB.md) | The minimal `ignidweb` HTTP server library |
| [docs/IGCURL.md](docs/IGCURL.md) | The `igcurl` HTTP client / downloader |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Honest list of current limitations and rough edges |
| [demos/](demos/) | Runnable example programs, from "hello world" to a full web app |

## A quick tour

```
// records act as simple classes: free functions take the instance as their
// first argument, since Ignid has no obj.method() syntax
rec Account [ text owner: int balance: ]

fn deposit(Account a, int amount) -> int [
    a.balance = a.balance + amount:
    give a.balance:
]

fn describe(Account a) -> text [
    give a.owner + ": $" + totext(a.balance):
]

start [
    let Account acc = Account("Alice", 100):
    deposit(acc, 50):
    iglog(describe(acc)):          // Alice: $150

    // try/catch around runtime errors
    try [
        let int bad = toint("not a number"):
    ] catch [
        iglog("caught:", lasterror()):
    ]

    // map, float, string interpolation
    let map scores = map_new():
    map_set(scores, "alice", 97.5):
    let float s = map_get_float(scores, "alice"):
    iglog("score: ${s}"):
]
```

See [demos/demo.ig](demos/demo.ig) for a longer tour covering nearly every language
feature, and [demos/demoweb.ig](demos/demoweb.ig) for a small web app.

## License

Ignid is open source under the [Apache License 2.0](LICENSE) — free to use,
modify, and redistribute, including for commercial projects. The "Ignid" name
and logo are trademarks and not covered by the code license — see
[TRADEMARK.md](TRADEMARK.md) if you're forking or redistributing.
