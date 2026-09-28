# Building the Compiler Toolchain

Ignid is self-hosted: `checker.ig`, `irgen.ig`, `opt.ig`, and `codegen.ig` — the
type checker, IR generator, optimizer, and code generator — are themselves written
in Ignid and compiled by the existing toolchain. This matters if you ever edit the
compiler's own source (e.g. after changing the hardcoded tool paths in `ignidc.ig`,
or if you're extending the language itself).

## The pipeline

`ignidc.exe` drives six stages for any `.ig` file:

```
check → irgen → opt → codegen → nasm → link
```

1. **check** (`checker_s11.exe`) — type-checks the source
2. **irgen** (`irgen_s10.exe`) — lexes/parses/emits label-based IR
3. **opt** (`opt.exe`) — a few peephole/dead-code optimization passes over the IR
4. **codegen** (`codegen_s11.exe`) — emits NASM assembly from the optimized IR
5. **nasm** — assembles to a `.obj`
6. **link** — links against `msvcrt.lib` + `kernel32.Lib` + `WS2_32.Lib` to produce
   the final `.exe`

## Rebuilding a compiler-stage file

If you edit `checker.ig`, `irgen.ig`, `opt.ig`, or `codegen.ig`, the new behavior
only takes effect once you **recompile that file with the existing toolchain and
promote the result**:

```
echo checker.ig | ignidc
copy checker.exe checker_s11.exe
```

The `_s11`/`_s10` suffix in the promoted filenames is just a naming convention from
this project's history (bootstrap generation numbers) — `ignidc.ig`'s `IG_CHECK`/
`IG_IRGEN`/`IG_CG` constants point at whichever files currently hold those suffixes.

### Self-consistency check

After promoting, it's worth recompiling the *same* file again with the newly
promoted tool, to confirm it produces a stable, working compiler (not just one that
happened to compile once):

```
echo checker.ig | ignidc
```

If this second compile also succeeds, the change is safe to keep. If you're
changing `codegen.ig` specifically, do this — codegen bugs are the ones most likely
to make the compiler unable to compile *itself* afterward.

### The self-overwrite gotcha

`ignidc.exe` cannot overwrite itself while running (Windows locks a running `.exe`).
To rebuild `ignidc.ig` itself:

```
copy ignidc.ig ignidc_new.ig
echo ignidc_new.ig | ignidc
copy ignidc_new.exe ignidc.exe
del ignidc_new.*
```

### Full rebuild order

After a `codegen.ig` change in particular, rebuild everything downstream in this
order, since each stage's `.exe` is used to compile the next:

```
codegen.ig  -> promote codegen_s11.exe (and codegen_s10.exe)
checker.ig  -> promote checker_s11.exe
irgen.ig    -> promote irgen_s10.exe
opt.ig      -> promote opt.exe
ignidc.ig   -> promote ignidc.exe (via the self-overwrite workaround above)
ignid.ig    -> promote ignid.exe
```

Then run the regression suite:

```
echo test_std.ig | ignidc
test_std.exe
```

It should print `ALL TESTS PASSED`.

## A note on `codegen.ig`'s runtime library

`codegen.ig`'s `gen_runtime()` emits the *entire* runtime support library (memory
allocator, string helpers, list/map helpers, socket helpers, try/catch machinery,
etc.) into **every** program it compiles, regardless of whether that specific
program uses all of it. This has one consequence worth knowing: if a `codegen.ig`
change breaks something in that shared runtime, it breaks *every* program compiled
by the new `codegen.exe` — including recompiling `codegen.ig` itself next time. If
you get stuck in a state where the current `codegen_s11.exe` can no longer compile
anything correctly, keep an older, known-good `codegen_s10.exe`/`codegen_s11.exe`
around as a fallback to bootstrap forward from.
