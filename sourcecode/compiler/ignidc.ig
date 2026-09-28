// ignidc.ig — Ignid Compiler Driver (Stage 11)
// Compiles a .ig source file to a native Windows .exe in one command.
// Usage: echo "path/to/source.ig" | ignidc.exe
use "d:/Ignid/std.ig":

// ===== TOOL PATHS =====
// IG_DIR is resolved at runtime to wherever ignidc.exe actually lives (via
// exedir()), so the compiler-stage binaries are always found relative to the
// install location instead of a hardcoded dev path.
//
// IG_NASM/IG_LINK/IG_MSVCRT/IG_KERNEL/IG_WS2 are loaded from a config file,
// "<IG_DIR>/ignid_paths.cfg" (KEY=VALUE lines: NASM/LINK/MSVCRT/KERNEL32/WS2_32),
// written by the installer after auto-detecting NASM + Visual Studio's MSVC
// toolset + Windows SDK on the target machine (see installer.ig). If that file
// doesn't exist at all, this is a dev checkout that hasn't been installed — fall
// back to this machine's known-good paths below.
let text IG_DIR    = exedir():
let text IG_CHECK  = IG_DIR + "/checker_s11.exe":
let text IG_IRGEN  = IG_DIR + "/irgen_s10.exe":
let text IG_OPT    = IG_DIR + "/opt.exe":
let text IG_CG     = IG_DIR + "/codegen_s11.exe":
let text IG_NASM   = "":
let text IG_LINK   = "":
let text IG_MSVCRT = "":
let text IG_KERNEL = "":
let text IG_WS2    = "":
let text IG_RC     = "":

fn cfg_get(list lines, text key, text fallback) -> text [
    let text pfx = key + "=":
    let int i = 0: let int n = len(lines):
    loop while i < n [
        let text ln = trim(lines{i}):
        when starts_with(ln, pfx) [
            let text v = sub(ln, len(pfx), len(ln)):
            when len(v) > 0 [ give v: ]
        ]
        i = i + 1:
    ]
    give fallback:
]

// Loads IG_NASM/IG_LINK/IG_MSVCRT/IG_KERNEL/IG_WS2 from ignid_paths.cfg if present,
// else falls back to this dev machine's own toolchain (so a plain checkout of the
// source still builds without running the installer).
fn load_tool_paths() -> int [
    let text cfgpath = IG_DIR + "/ignid_paths.cfg":
    let int have_cfg = 1:
    let text raw = "":
    try [
        raw = readfile(cfgpath):
    ]
    catch [
        have_cfg = 0:
    ]
    when have_cfg == 1 [
        let list lines = split(raw, "\n"):
        IG_NASM   = cfg_get(lines, "NASM",     ""):
        IG_LINK   = cfg_get(lines, "LINK",     ""):
        IG_MSVCRT = cfg_get(lines, "MSVCRT",   ""):
        IG_KERNEL = cfg_get(lines, "KERNEL32", ""):
        IG_WS2    = cfg_get(lines, "WS2_32",   ""):
        IG_RC     = cfg_get(lines, "RC",       ""):
        give 0:
    ]
    IG_NASM   = "C:/Program Files/NASM/nasm.exe":
    IG_LINK   = "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.51.36231/bin/HostX64/x64/link.exe":
    IG_MSVCRT = "C:/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.51.36231/lib/x64/msvcrt.lib":
    IG_KERNEL = "C:/Program Files (x86)/Windows Kits/10/Lib/10.0.28000.0/um/x64/kernel32.Lib":
    IG_WS2    = "C:/Program Files (x86)/Windows Kits/10/Lib/10.0.28000.0/um/x64/WS2_32.Lib":
    IG_RC     = "C:/Program Files (x86)/Windows Kits/10/bin/10.0.28000.0/x64/rc.exe":
    give 0:
]

// Runs immediately at program startup (top-level statements execute as part of
// global init, regardless of which file's `start` block ends up as the entry
// point — see note on the `start` block below for why this can't just live there).
load_tool_paths():
when len(IG_NASM) == 0 or len(IG_LINK) == 0 [
    iglog("[ignidc] error: NASM or the MSVC linker could not be located."):
    iglog("[ignidc] Install Visual Studio Build Tools (\"Desktop development with"):
    iglog("[ignidc] C++\" workload), then re-run the Ignid installer."):
    quit(1):
]

// ===== PATH HELPERS =====

fn basename_noext(text path) -> text [
    let int n = len(path):
    let int slash = -1: let int dot = -1: let int i = n - 1:
    loop while i >= 0 [
        when (path{i} == "/" or path{i} == "\\") and slash < 0 [ slash = i: ]
        when path{i} == "." and dot < 0 [ dot = i: ]
        i = i - 1:
    ]
    let int ns = slash + 1:
    let int ne = n:
    when dot > ns [ ne = dot: ]
    give sub(path, ns, ne):
]

fn dir_of(text path) -> text [
    let int n = len(path): let int i = n - 1:
    loop while i >= 0 [
        when path{i} == "/" or path{i} == "\\" [ give sub(path, 0, i + 1): ]
        i = i - 1:
    ]
    give "":
]

fn slash_to_back(text path) -> text [
    let text r = "": let int i = 0: let int n = len(path):
    loop while i < n [
        when path{i} == "/" [ r = r + "\\": ]
        else [ r = r + path{i}: ]
        i = i + 1:
    ]
    give r:
]

// Quote a path for cmd.exe (wrap in double-quotes)
fn qpath(text p) -> text [ give "\"" + p + "\"": ]

// cmd.exe's built-in `mkdir`/`del` misparse paths with more than one forward
// slash — convert to real backslashes before handing them a path.
fn winpath(text p) -> text [
    let text bs = chr(92):
    let text out = "":
    let int i = 0: let int n = len(p):
    loop while i < n [
        when p{i} == "/" [ out = out + bs: ]
        else [ out = out + p{i}: ]
        i = i + 1:
    ]
    give out:
]

// ===== PIPELINE RUNNER =====

// Set to 1 by ignid.ig (compile-and-run) so only the program's own output
// shows, not the pipeline's progress chatter. ignidc's own entry point (an
// explicit "give me a distributable .exe" request) leaves this at 0, since
// seeing stage-by-stage progress and the final .exe's location is the point.
// Errors are never suppressed either way.
let int g_quiet = 0:

fn run_stage(text label, text cmd) -> int [
    when g_quiet == 0 [ iglog("[ignidc] " + label): ]
    let int r = system(cmd):
    when r != 0 [
        iglog("[ignidc] ERROR in " + label + " (exit " + totext(r) + ")"):
    ]
    give r:
]

fn compile(text src, text out_dir, text out_name) -> int [
    let text exe_f   = out_dir + out_name + ".exe":

    // Intermediate pipeline files (.ir/_opt.ir/.asm/.obj) are internal
    // implementation detail, not something a user compiling a program wants
    // left behind next to their source — build them in %TEMP% instead and
    // clean up after a successful build. Only the .exe ends up in out_dir.
    let text tmpdir  = getenv("TEMP") + "/ignid_build":
    system("mkdir \"" + winpath(tmpdir) + "\" 2>NUL"):
    let text base    = tmpdir + "/" + out_name:
    let text ir      = base + ".ir":
    let text opt_ir  = base + "_opt.ir":
    let text asm_f   = base + ".asm":
    let text obj_f   = base + ".obj":

    when g_quiet == 0 [
        iglog("[ignidc] source : " + src):
        iglog("[ignidc] output : " + exe_f):
        iglog("[ignidc] -------"):
    ]

    let int t0 = clock():

    // Stage 1 — Type checking (errors print to stderr; stdout status suppressed)
    let text cmd0 = "echo " + src + " | " + qpath(IG_CHECK) + " > NUL":
    when run_stage("1/6  check", cmd0) != 0 [ give 1: ]

    // Stage 2 — IR generation
    let text cmd1 = "echo " + src + " | " + qpath(IG_IRGEN) + " > " + qpath(ir) + " 2>NUL":
    when run_stage("2/6  irgen", cmd1) != 0 [ give 1: ]

    // Stage 3 — Optimization
    let text cmd2 = "echo " + ir + " | " + qpath(IG_OPT) + " > " + qpath(opt_ir) + " 2>NUL":
    when run_stage("3/6  opt  ", cmd2) != 0 [ give 1: ]

    // Stage 4 — Code generation (NASM)
    let text cmd3 = "echo " + opt_ir + " | " + qpath(IG_CG) + " > " + qpath(asm_f) + " 2>NUL":
    when run_stage("4/6  cg   ", cmd3) != 0 [ give 1: ]

    // Stage 5 — Assemble
    let text cmd4 = qpath(IG_NASM) + " -f win64 " + qpath(asm_f) + " -o " + qpath(obj_f):
    when run_stage("5/6  nasm ", cmd4) != 0 [ give 1: ]

    // Optional icon/manifest: if "<out_dir><out_name>.ico" and/or ".manifest"
    // exist and the resource compiler was found, embed them into the .exe.
    // A manifest matters beyond cosmetics: Windows' "Installer Detection"
    // auto-flags any .exe whose name contains "setup"/"install"/"update"/etc
    // as needing elevation unless it carries an explicit manifest saying
    // otherwise — an unmanifested "FooSetup.exe" launched non-elevated (e.g.
    // by another installer) fails outright with "CreateProcess failed; code
    // 740, The requested operation requires elevation." Either way this is
    // best-effort — never fails the build if these files or rc.exe are missing.
    let text ico_f = out_dir + out_name + ".ico":
    let text man_f = out_dir + out_name + ".manifest":
    let text res_f = base + ".res":
    let int have_icon = 0:
    let int have_manifest = 0:
    when len(IG_RC) > 0 [
        try [
            let int ih = file_open(ico_f):
            file_close(ih):
            have_icon = 1:
        ]
        catch [ have_icon = 0: ]
        try [
            let int mh = file_open(man_f):
            file_close(mh):
            have_manifest = 1:
        ]
        catch [ have_manifest = 0: ]
    ]
    let text link_extra = "":
    when have_icon == 1 or have_manifest == 1 [
        let text rc_content = "":
        when have_icon == 1 [ rc_content = rc_content + "1 ICON " + qpath(ico_f) + "\n": ]
        when have_manifest == 1 [ rc_content = rc_content + "1 24 " + qpath(man_f) + "\n": ]
        let text rc_f = base + ".rc":
        writefile(rc_f, rc_content):
        // rc.exe with no /fo writes "<rcfile-without-.rc>.res" next to the .rc
        // file by default — which is exactly res_f (base + ".res") here.
        let text cmd_rc = qpath(IG_RC) + " " + qpath(rc_f) + " > NUL 2>&1":
        when system(cmd_rc) == 0 [ link_extra = " " + qpath(res_f): ]
        system("del \"" + winpath(rc_f) + "\" 2>NUL"):
    ]

    // Stage 6 — Link
    let text cmd5 = qpath(IG_LINK) + " /subsystem:console /entry:ig_start /nodefaultlib " + qpath(obj_f) + link_extra + " " + qpath(IG_MSVCRT) + " " + qpath(IG_KERNEL) + " " + qpath(IG_WS2) + " /out:" + qpath(exe_f) + " > NUL 2>&1":
    when run_stage("6/6  link ", cmd5) != 0 [ give 1: ]

    system("del \"" + winpath(ir) + "\" \"" + winpath(opt_ir) + "\" \"" + winpath(asm_f) + "\" \"" + winpath(obj_f) + "\" \"" + winpath(res_f) + "\" 2>NUL"):

    when g_quiet == 0 [
        let int elapsed = clock() - t0:
        iglog("[ignidc] -------"):
        iglog("[ignidc] done in " + totext(elapsed) + " ms  ->  " + exe_f):
    ]
    give 0:
]

// ===== ENTRY =====

// NOTE: when this file is `use`d by ignid.ig (which has its own `start` block),
// this `start` block's body is NOT the one that ends up running — ignid.ig's is.
// That's why load_tool_paths() above is a top-level call, not the first line here.
start [
    iglog.err("Source (.ig): "):
    let text src = trim(ask("")):
    // Strip UTF-8 BOM (EF BB BF = bytes 239 187 191) added by some terminals
    when len(src) >= 3 [
        when ord(sub(src, 0, 1)) == 239 and ord(sub(src, 1, 2)) == 187 and ord(sub(src, 2, 3)) == 191 [
            src = sub(src, 3, len(src)):
        ]
    ]
    when len(src) == 0 [
        iglog("[ignidc] error: no source file given"):
        quit(1):
    ]
    // Remove surrounding quotes if user pasted a quoted path
    when starts_with(src, "\"") and ends_with(src, "\"") [
        src = sub(src, 1, len(src) - 1):
    ]
    let text d    = dir_of(src):
    let text name = basename_noext(src):
    when len(name) == 0 [ iglog("[ignidc] error: cannot parse filename"): quit(1): ]
    let int ok = compile(src, d, name):
    when ok != 0 [ quit(1): ]
]
