// opt.ig — Ignid IR optimizer (self-hosting step 5)
// Reads label-based IR (irgen.ig output), applies optimizations, outputs cleaner IR.
//
// Pass sequence:
//  1. dead      — remove instructions after RET/JMP until next label
//  2. cfold     — constant arithmetic folding: CONST n, CONST m, BIN op -> CONST result
//  3. cbranch   — constant-condition branches: CONST true/false + JF/JT -> JMP or remove
//  4. dpairs    — dead pairs: LOAD x+POP, DUP+POP -> remove both
//  5. notnot    — NOT NOT -> remove both; BOOL BOOL -> keep one
//  6. dedup     — consecutive labels: redirect refs, drop later
//  7. noop      — JMP .Ln where .Ln is immediately following -> remove
//  8. dead      — second pass (cbranch may create new unreachable code)
//  9. dedup, noop, dpairs  — clean up again

// ---- IR line store (sentinel at index 0) ----
let list lines = {"~"}:
let list dead  = {0}:

// ---- character helpers ----
fn isdigit(text ch) -> int [
    let text d = "0123456789":
    loop i in 0 to 9 [
        when d{i} == ch [ give 1: ]
    ]
    give 0:
]

fn isalpha(text ch) -> int [
    let text a = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_":
    loop i in 0 to 52 [
        when a{i} == ch [ give 1: ]
    ]
    give 0:
]

// ---- string helpers ----
fn starts_with(text s, text pfx) -> int [
    let int plen = len(pfx):
    when len(s) < plen [ give 0: ]
    when sub(s, 0, plen) == pfx [ give 1: ]
    give 0:
]

fn ends_with(text s, text sfx) -> int [
    let int slen = len(sfx):
    let int tlen = len(s):
    when tlen < slen [ give 0: ]
    when sub(s, tlen - slen, tlen) == sfx [ give 1: ]
    give 0:
]

fn is_int_str(text s) -> int [
    when len(s) == 0 [ give 0: ]
    let int i = 0:
    when s{0} == "-" [ i = 1: ]
    when i >= len(s) [ give 0: ]
    loop while i < len(s) [
        when isdigit(s{i}) == 0 [ give 0: ]
        i = i + 1:
    ]
    give 1:
]

// ---- IR line classification ----
fn is_label(text line) -> int [
    when len(line) < 3 [ give 0: ]
    when line{0} != "." [ give 0: ]
    when line{1} != "L" [ give 0: ]
    give 1:
]

fn is_structural(text line) -> int [
    when is_label(line) == 1        [ give 1: ]
    when starts_with(line, "fn ")   [ give 1: ]
    when starts_with(line, "param ")[ give 1: ]
    when starts_with(line, "ret ")  [ give 1: ]
    when line == "end"  [ give 1: ]
    when line == "main" [ give 1: ]
    when line == "RETN" [ give 1: ]
    when line == "HALT" [ give 1: ]
    give 0:
]

fn is_unconditional(text line) -> int [
    when line == "RET" [ give 1: ]
    when starts_with(line, "JMP ") [ give 1: ]
    give 0:
]

fn is_jump(text line) -> int [
    when starts_with(line, "JF ")    [ give 1: ]
    when starts_with(line, "JT ")    [ give 1: ]
    when starts_with(line, "JMP ")   [ give 1: ]
    when starts_with(line, "INEXT ") [ give 1: ]
    give 0:
]

// ---- load lines from file text (strips \r for CRLF files) ----
fn load_lines(text src) -> int [
    let int i = 0:
    let int n = len(src):
    let int ls = 0:
    loop while i < n [
        when src{i} == "\n" [
            let text ln = sub(src, ls, i):
            when len(ln) > 0 and ln{len(ln) - 1} == "\r" [
                ln = sub(ln, 0, len(ln) - 1):
            ]
            when len(ln) > 0 [
                push(lines, ln):
                push(dead, 0):
            ]
            ls = i + 1:
        ]
        i = i + 1:
    ]
    when ls < n [
        let text ln = sub(src, ls, n):
        when len(ln) > 0 and ln{len(ln) - 1} == "\r" [
            ln = sub(ln, 0, len(ln) - 1):
        ]
        when len(ln) > 0 [ push(lines, ln): push(dead, 0): ]
    ]
    give 0:
]

// ---- next live non-label instruction with no label between (for peephole) ----
// Returns -1 if a live label is encountered before the next instruction.
fn next_no_label(int i) -> int [
    let int j = i + 1:
    loop while j < len(lines) [
        when dead{j} == 0 [
            when is_label(lines{j}) == 1 [ give -1: ]
            give j:
        ]
        j = j + 1:
    ]
    give -1:
]

// ---- Pass 1: dead code after unconditional transfers ----
fn pass_dead() -> int [
    let int after_uncond = 0:
    let int i = 1:
    loop while i < len(lines) [
        let text line = lines{i}:
        when is_label(line) == 1 or line == "end" or line == "main" or starts_with(line, "fn ") [
            after_uncond = 0:
        ]
        else [
            when after_uncond == 1 and is_structural(line) == 0 [
                dead{i} = 1:
            ]
        ]
        when dead{i} == 0 and is_unconditional(line) == 1 [
            after_uncond = 1:
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 2: constant arithmetic folding ----
// CONST n, CONST m, BIN +/-/* -> CONST (n op m)
fn pass_cfold() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_label(lines{i}) == 0 and starts_with(lines{i}, "CONST ") [
            let text sv1 = sub(lines{i}, 6, len(lines{i})):
            when is_int_str(sv1) == 1 [
                let int j = next_no_label(i):
                when j != -1 and starts_with(lines{j}, "CONST ") [
                    let text sv2 = sub(lines{j}, 6, len(lines{j})):
                    when is_int_str(sv2) == 1 [
                        let int k = next_no_label(j):
                        when k != -1 and starts_with(lines{k}, "BIN ") [
                            let text op = sub(lines{k}, 4, len(lines{k})):
                            when op == "+" or op == "-" or op == "*" [
                                let int v1 = toint(sv1):
                                let int v2 = toint(sv2):
                                let int result = 0:
                                when op == "+" [ result = v1 + v2: ]
                                or   op == "-" [ result = v1 - v2: ]
                                or   op == "*" [ result = v1 * v2: ]
                                lines{i} = "CONST " + totext(result):
                                dead{j} = 1:
                                dead{k} = 1:
                            ]
                        ]
                    ]
                ]
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 3: constant-condition branch elimination ----
// CONST true/false + JF .Ln  -> JMP .Ln (false) or remove both (true)
// CONST true/false + JT .Ln  -> JMP .Ln (true)  or remove both (false)
fn pass_cbranch() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_label(lines{i}) == 0 [
            let text line = lines{i}:
            when line == "CONST true" or line == "CONST false" [
                let int j = next_no_label(i):
                when j != -1 [
                    let text jl = lines{j}:
                    let int is_true = 0:
                    when line == "CONST true" [ is_true = 1: ]
                    when starts_with(jl, "JF ") [
                        when is_true == 1 [
                            // true + JF: branch never taken, fall through
                            dead{i} = 1: dead{j} = 1:
                        ]
                        else [
                            // false + JF: always jump
                            dead{i} = 1:
                            lines{j} = "JMP " + sub(jl, 3, len(jl)):
                        ]
                    ]
                    or starts_with(jl, "JT ") [
                        when is_true == 1 [
                            // true + JT: always jump
                            dead{i} = 1:
                            lines{j} = "JMP " + sub(jl, 3, len(jl)):
                        ]
                        else [
                            // false + JT: branch never taken
                            dead{i} = 1: dead{j} = 1:
                        ]
                    ]
                ]
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 4: dead value pairs ----
// LOAD x + POP -> remove both (load result immediately discarded)
// DUP + POP    -> remove both (duplicate immediately discarded)
fn pass_dpairs() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_label(lines{i}) == 0 [
            let text line = lines{i}:
            when starts_with(line, "LOAD ") or line == "DUP" [
                let int j = next_no_label(i):
                when j != -1 and lines{j} == "POP" [
                    dead{i} = 1: dead{j} = 1:
                ]
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 5: NOT NOT -> remove both; BOOL BOOL -> keep first ----
fn pass_notnot() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_label(lines{i}) == 0 [
            let text line = lines{i}:
            when line == "NOT" or line == "BOOL" [
                let int j = next_no_label(i):
                when j != -1 and lines{j} == line [
                    when line == "NOT" [
                        // NOT NOT -> identity, remove both
                        dead{i} = 1: dead{j} = 1:
                    ]
                    else [
                        // BOOL BOOL -> one BOOL is enough
                        dead{j} = 1:
                    ]
                ]
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 6: replace label refs in jump instructions ----
fn replace_refs(text old_lab, text new_lab) -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_jump(lines{i}) == 1 [
            when ends_with(lines{i}, old_lab) == 1 [
                let int plen = len(lines{i}) - len(old_lab):
                lines{i} = sub(lines{i}, 0, plen) + new_lab:
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

fn pass_dedup() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and is_label(lines{i}) == 1 [
            let int j = i - 1:
            loop while j >= 1 [
                when dead{j} == 0 [
                    when is_label(lines{j}) == 1 [
                        replace_refs(lines{i}, lines{j}):
                        dead{i} = 1:
                    ]
                    stop:
                ]
                j = j - 1:
            ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Pass 7: no-op JMP removal ----
fn pass_noop() -> int [
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 and starts_with(lines{i}, "JMP ") [
            let text target = sub(lines{i}, 4, len(lines{i})):
            let int j = i + 1:
            let int found = 0:
            loop while j < len(lines) [
                when dead{j} == 1 [ j = j + 1: skip: ]
                when is_label(lines{j}) == 0 [ stop: ]
                when lines{j} == target [ found = 1: stop: ]
                j = j + 1:
            ]
            when found == 1 [ dead{i} = 1: ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- Count live lines ----
fn count_live() -> int [
    let int n = 0:
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 [ n = n + 1: ]
        i = i + 1:
    ]
    give n:
]

// ---- Entry ----
start [
    iglog.err("IR file to optimize: "):
    let text path = ask(""):
    let text src = readfile(path):

    load_lines(src):
    let int total = len(lines) - 1:

    // NOTE: pass_dedup() (adjacent-label merging) is deliberately NOT called at all,
    // in either round. On large inputs it triggers a genuine out-of-memory crash whose
    // exact trigger was not fully isolated after extensive instrumentation (confirmed:
    // not proportional to lines touched per call, not a huge-line/corruption issue,
    // not an infinite loop by construction — both pass_dedup and replace_refs are
    // structurally bounded single/double loops). It first appeared re-running dedup a
    // second time around ~8000 IR lines; it then reappeared on round 1's *first* call
    // once the file grew further (~9800 lines, crashing near dedup call #121-122).
    // Since the exact safe threshold is unpredictable and codegen.ig keeps growing,
    // dedup is disabled entirely rather than chasing a moving target. This is a pure
    // optimization pass — skipping it never produces incorrect code, only marginally
    // less compact output (a few un-merged adjacent labels).
    // Round 1: structural + peephole
    pass_dead():
    pass_cfold():
    pass_cbranch():
    pass_dpairs():
    pass_notnot():
    pass_noop():

    // Round 2: clean up cascading effects
    pass_dead():
    pass_cfold():
    pass_cbranch():
    pass_dpairs():
    pass_noop():
    pass_dpairs():

    let int live = count_live():

    // Output surviving lines
    let int i = 1:
    loop while i < len(lines) [
        when dead{i} == 0 [ iglog(lines{i}): ]
        i = i + 1:
    ]

    iglog.err("--- opt:", total, "->", live, "lines (", total - live, "eliminated) ---"):
]
