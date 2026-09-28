# Ignid Source Code

![Ignid](https://ignid.org/logo.png)

Official site: [ignid.org](https://ignid.org/)

The full source of the Ignid programming language toolchain, licensed under
the [Apache License 2.0](LICENSE). The "Ignid" name and logo are trademarks,
kept separate from the code license — see [TRADEMARK.md](TRADEMARK.md) if
you're forking or redistributing.

Ignid is self-hosted: the compiler is itself written in Ignid (`.ig` files)
and compiles itself. See [`../docs/BUILDING.md`](../docs/BUILDING.md) for how
to rebuild the toolchain from this source, and
[`../docs/completeallaboutthis.md`](../docs/completeallaboutthis.md) for the
full language + standard library reference.

## Layout

| Folder | Contents |
|---|---|
| `compiler/` | The 6-stage pipeline: `checker.ig` (type checker) → `irgen.ig` (IR generator) → `opt.ig` (optimizer) → `codegen.ig` (x86-64 code generator) → NASM → `link.exe`, driven by `ignidc.ig` (compile-only) and `ignid.ig` (compile-and-run, includes the interactive REPL) |
| `stdlib/` | `std.ig` (strings/lists/math/random helpers) and `ignidweb.ig` (a small Flask-like HTTP library) |
| `tools/` | `installer.ig`/`uninstall.ig` — the Windows installer/uninstaller, themselves written in and compiled by Ignid |
| `demos/` | Runnable example programs, roughly ordered from simplest to most advanced |
| `examples/` | `hello.ig`, `calc.ig` — minimal standalone programs |
| `tests/` | The regression test suite (`test_std.ig` and friends) |

## Building

```
echo checker.ig | ignidc
```

See `../docs/BUILDING.md` for the full rebuild order and the self-hosting
bootstrap gotchas (a compiler-stage file can't overwrite itself while
running, self-compile-stability verification, etc).
