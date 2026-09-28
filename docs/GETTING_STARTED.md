# Getting Started

## Prerequisites

Ignid compiles to native Windows executables via NASM + the MSVC linker, so both
need to be installed first:

1. **NASM** — download from [nasm.us](https://www.nasm.us/) and install it, or
   install it via a package manager (e.g. `winget install NASM.NASM`).
2. **Visual Studio Build Tools** (or full Visual Studio) with the **"Desktop
   development with C++"** workload checked during install. This provides
   `link.exe` and the Windows SDK import libraries (`kernel32.Lib`, `WS2_32.Lib`)
   that every compiled Ignid program links against.

## Pointing the compiler at your toolchain

Open `ignidc.ig` and check the tool-path constants near the top:

```
let text IG_NASM   = "...\nasm.exe":
let text IG_LINK   = "...\link.exe":
let text IG_MSVCRT = "...\msvcrt.lib":
let text IG_KERNEL = "...\kernel32.Lib":
let text IG_WS2    = "...\WS2_32.Lib":
```

These are plain file paths — if NASM or Visual Studio installed somewhere other
than what's already there, update the paths to match your machine, then rebuild
`ignidc.exe` (see [BUILDING.md](BUILDING.md)).

## Compiling your first program

Create `hello.ig`:

```
start [
    iglog("Hello, Ignid!"):
]
```

Compile and run it in one step:

```
> ignid hello.ig
Hello, Ignid!
```

`ignid` compiles `hello.ig` to `hello.exe` in the same folder, then runs it
immediately. If you only want to compile (without running), use `ignidc` instead —
it reads the source path from stdin:

```
> echo hello.ig | ignidc
```

## Adding `ignid` to your PATH

So you can run `ignid file.ig` from any directory, add the folder containing
`ignid.exe` to your user `PATH`:

```powershell
$cur = [Environment]::GetEnvironmentVariable("Path","User")
[Environment]::SetEnvironmentVariable("Path", $cur.TrimEnd(';') + ";D:\path\to\Ignid", "User")
```

Open a **new** terminal window afterward — existing ones won't pick up the change.

## Command-line usage

```
ignid <file.ig> [args...]     compile and run, passing args... to the program
ignid --version               print the compiler version
```

Inside a running program, `argc()` / `argv(i)` read back whatever was passed after
the filename.

## Next steps

- [LANGUAGE.md](LANGUAGE.md) — the full language reference
- [STDLIB.md](STDLIB.md) — built-in and standard-library functions
- [demos/](../demos/) — runnable example programs, roughly ordered from simplest to
  most advanced
