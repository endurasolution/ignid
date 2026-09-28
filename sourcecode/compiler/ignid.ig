// ignid.ig — Ignid CLI: compiles AND runs a .ig source file in one command.
// Usage: ignid <file.ig> [args passed through to the compiled program]
//        ignid --version | -v | --v
use "d:/Ignid/ignidc.ig":

let text IGNID_VERSION = "1.0.0":

// Interactive REPL — launched when `ignid` is run with no arguments, mirroring
// `node` with no args. Ignid has no interpreter/incremental compilation, so
// each line is folded into a growing hidden `start [...]` block and the WHOLE
// thing is recompiled+run fresh every turn (variables persist because they're
// still right there in the accumulated source). To avoid every earlier turn's
// output replaying on every subsequent turn, this uses Ignid's own statement
// terminator as the signal: a line ending in ":" is a normal statement (run
// once, folded into history silently — e.g. `let x = 5:`); a line with NO
// trailing ":" is treated as a bare expression to evaluate and print THIS
// turn only (e.g. `x + 3`), never added to history, so it can't re-print
// later. (If you explicitly call iglog/print/println inside a ":"-terminated
// statement, that output — like any real statement's side effect — reruns
// every subsequent turn along with the rest of history; prefer the
// no-colon expression form for one-off "show me this value" queries.)
fn run_repl() -> int [
    iglog("Ignid v" + IGNID_VERSION + " — interactive REPL"):
    iglog("Type \".help\" for more information."):
    iglog(""):

    let text history = "":
    let text rundir = getenv("TEMP") + "/ignid_repl/":
    system("mkdir \"" + winpath(rundir) + "\" 2>NUL"):

    // ig_readline (behind ask()) does one raw ReadFile per call. On a real
    // interactive console that naturally yields one line at a time, but on
    // piped/redirected stdin a single read can return several lines already
    // sitting in the pipe buffer, joined by embedded "\n"s it never strips
    // (it only strips the trailing one). Every earlier use of ask() in this
    // codebase only ever read once per process, so this never mattered until
    // a loop like this one reads repeatedly — queue whatever ask() hands
    // back and drain it line-by-line before asking again.
    let list pending = list_new_text():
    let int blank_streak = 0:
    let int first_read = 1:

    loop while true [
        when len(pending) == 0 [
            let text chunk = ask("ignid> "):
            // Strip a UTF-8 BOM (EF BB BF) some terminals/pipes prepend to the
            // very first thing written to stdin — same defensive check
            // ignidc.ig does for its own (single) stdin read.
            when first_read == 1 [
                first_read = 0:
                when len(chunk) >= 3 [
                    when ord(sub(chunk, 0, 1)) == 239 and ord(sub(chunk, 1, 2)) == 187 and ord(sub(chunk, 2, 3)) == 191 [
                        chunk = sub(chunk, 3, len(chunk)):
                    ]
                ]
            ]
            let list parts = split(chunk, chr(10)):
            let int pi = 0: let int pn = len(parts):
            loop while pi < pn [
                push(pending, trim(parts{pi})):
                pi = pi + 1:
            ]
        ]
        let text raw = pending{0}:
        pending = list_slice(pending, 1, len(pending)):

        when len(raw) == 0 [
            // ask() returns "" both for a genuine blank line AND for a closed/
            // EOF stdin (there's no builtin way to tell them apart), so a
            // piped session with no explicit .exit would otherwise spin here
            // forever re-reading nothing. A real interactive user hitting
            // blank Enter a few times in a row is vanishingly unlikely, so
            // treat a run of blanks as "stdin is gone" and exit gracefully.
            blank_streak = blank_streak + 1:
            when blank_streak >= 3 [ stop: ]
            skip:
        ]
        blank_streak = 0:

        when raw == ".exit" or raw == ".quit" [ stop: ]
        when raw == ".help" [
            iglog("End a line with ':' to run it as a statement, e.g.:"):
            iglog("    let text m = \"hello world\": iglog(m):"):
            iglog("Leave off the trailing ':' to evaluate and print an expression, e.g.:"):
            iglog("    m"):
            iglog(""):
            iglog("Commands:"):
            iglog("  .clear    forget all variables/state from this session"):
            iglog("  .exit     quit the REPL"):
            skip:
        ]
        when raw == ".clear" [
            history = "":
            iglog("(session state cleared)"):
            skip:
        ]
        when len(raw) == 0 [ skip: ]

        let int is_expr = 0:
        let text stmt = raw:
        when not ends_with(raw, ":") [
            is_expr = 1:
            stmt = "printout(\"=> \"): iglog(" + raw + "):":
        ]

        let text srcpath = rundir + "session.ig":
        writefile(srcpath, "start [\n" + history + "\n    " + stmt + "\n]\n"):

        g_quiet = 1:
        let int ok = compile(srcpath, rundir, "session"):
        when ok == 0 [
            let text exe_f = rundir + "session.exe":
            system(qpath(exe_f)):
            system("del \"" + winpath(exe_f) + "\" 2>NUL"):
            when is_expr == 0 [ history = history + "\n    " + stmt: ]
        ]
        when ok != 0 [
            iglog("  (not saved to session state — fix and retry)"):
        ]
    ]
    system("del \"" + winpath(rundir + "session.ig") + "\" 2>NUL"):
    iglog("Goodbye!"):
    give 0:
]

start [
    when argc() == 0 [
        run_repl():
        quit(0):
    ]
    let text a0 = argv(0):
    when a0 == "--version" or a0 == "-v" or a0 == "--v" [
        iglog("Ignid Compiler v" + IGNID_VERSION):
        iglog("Target: Windows x86-64"):
        quit(0):
    ]
    let text src  = a0:
    let text name = basename_noext(src):
    when len(name) == 0 [ iglog("[ignid] error: cannot parse filename"): quit(1): ]

    // Unlike `ignidc` (an explicit "give me a distributable .exe" request),
    // `ignid` is a script-runner: only the PROGRAM's own output should show,
    // and nothing should be left behind next to the source. Build (and run)
    // entirely out of %TEMP% — quietly — then delete the .exe afterward.
    // (This also sidesteps needing a "run via bare filename" workaround: the
    // exe's path here is always a full absolute path, never a bare name.)
    g_quiet = 1:
    let text rundir = getenv("TEMP") + "/ignid_build/":
    let int ok = compile(src, rundir, name):
    when ok != 0 [ quit(1): ]

    let text exe_f  = rundir + name + ".exe":
    let text runcmd = qpath(exe_f):
    let int ai = 1:
    loop while ai < argc() [
        runcmd = runcmd + " " + qpath(argv(ai)):
        ai = ai + 1:
    ]
    let int rc = system(runcmd):
    system("del \"" + winpath(exe_f) + "\" 2>NUL"):
    quit(rc):
]
