// irgen.ig — Ignid IR generator (self-hosting step 4)
// Reads a .ig source file, lexes it, and emits label-based text IR to stdout.

// ---- global token store (sentinel at index 0) ----
let list tk = {"~"}:
let list tv = {"~"}:
let int ntok = 1:
let int pos = 1:

// ---- label counter ----
let int nlabs = 0:

// ---- loop stacks (sentinel so native type is known) ----
let list brk_labs = {-1}:
let list cnt_labs = {-1}:
let list loop_try_lv = {-1}:
let int try_depth = 0:

// ---- rec type + variable type tables ----
let list rec_names = {"~"}:
let list var_n = {"~"}:
let list var_t = {"~"}:

// ---- enum type tables ----
let list enum_n = {"~"}:
let list enum_var_en = {"~"}:
let list enum_var_vn = {"~"}:
let int enum_var_total = 0:

// ---- module inclusion tracking ----
let list used_files = {}:

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

fn iskeyword(text w) -> int [
    let list kws = {"let","fix","any","var","int","float","text","bool",
                    "list","map","true","false","fn","give","start","loop",
                    "in","to","step","while","when","or","and","not","else",
                    "stop","skip","iglog","rec","enum","use","match","try","catch","private",
                    "spawn","yield"}:
    loop k in kws [
        when k == w [ give 1: ]
    ]
    give 0:
]

fn esc(text s) -> text [
    let text out = "":
    let int i = 0:
    let int n = len(s):
    loop while i < n [
        let text c = s{i}:
        when c == "\n" [ out = out + "\\n": i = i + 1: skip: ]
        when c == "\r" [ out = out + "\\r": i = i + 1: skip: ]
        when c == "\t" [ out = out + "\\t": i = i + 1: skip: ]
        when c == "\\" [ out = out + "\\\\": i = i + 1: skip: ]
        out = out + c:
        i = i + 1:
    ]
    give out:
]

// ---- module: strip start block from included files ----
fn strip_start(text src) -> text [
    let int n = len(src): let int i = 0:
    loop while i < n [
        let int found = 0:
        when i + 7 <= n [ when sub(src, i, i + 7) == "start [" [ found = 1: ] ]
        when found == 1 [
            let text before = sub(src, 0, i):
            let int d = 0: let int j = i + 6:
            loop while j < n [
                when src{j} == "[" [ d = d + 1: ]
                or src{j} == "]" [
                    d = d - 1:
                    when d == 0 [ give before + sub(src, j + 1, n): ]
                ]
                j = j + 1:
            ]
            give before:
        ]
        i = i + 1:
    ]
    give src:
]

// See resolve_use_path in checker.ig for the full rationale: a bare `use`
// filename (no separator) resolves relative to CWD first (so a project's own
// sibling files keep working), falling back to the compiler's own directory
// only if not found there (so `use "std.ig":` works from any folder).
fn resolve_use_path(text upath) -> text [
    let text bs = chr(92):
    let int has_sep = 0: let int si = 0: let int sn = len(upath):
    loop while si < sn [
        when upath{si} == "/" or upath{si} == bs [ has_sep = 1: stop: ]
        si = si + 1:
    ]
    when has_sep == 1 [ give upath: ]
    let int found_local = 1:
    try [
        let int h = file_open(upath):
        file_close(h):
    ]
    catch [ found_local = 0: ]
    when found_local == 1 [ give upath: ]
    give exedir() + "/" + upath:
]

fn expand_uses(text src) -> text [
    // segment-based O(n) expansion: skip string literals/comments to avoid false positives
    let int n = len(src): let int i = 0:
    let text result = "": let int seg = 0:
    loop while i < n [
        // skip string literal — never detect 'use "' inside strings
        when src{i} == "\"" [
            i = i + 1:
            let int es = 0:
            loop while es == 0 [
                when i >= n [ es = 1: stop: ]
                when src{i} == "\"" [ i = i + 1: es = 1: stop: ]
                when src{i} == "\\" [ i = i + 1: ]
                i = i + 1:
            ]
            skip:
        ]
        // skip line comment
        let int is_cmt = 0:
        when i + 1 < n [
            when src{i} == "/" [
                when src{i + 1} == "/" [ is_cmt = 1: ]
            ]
        ]
        when is_cmt == 1 [
            loop while i < n [ when src{i} == "\n" [ stop: ] i = i + 1: ]
            skip:
        ]
        // detect top-level use "path": directive
        let int umatch = 0:
        when i + 4 < n [
            when sub(src, i, i + 4) == "use " [
                when src{i + 4} == "\"" [ umatch = 1: ]
            ]
        ]
        when umatch == 1 [
            result = result + sub(src, seg, i):
            let int ps = i + 5: let int pe = ps:
            loop while pe < n [ when src{pe} == "\"" [ stop: ] pe = pe + 1: ]
            let text upath = sub(src, ps, pe):
            let int sk = pe + 1:
            loop while sk < n [ when src{sk} == ":" [ stop: ] sk = sk + 1: ]
            i = sk + 1: seg = i:
            let int already = 0:
            loop f in used_files [ when f == upath [ already = 1: ] ]
            when already == 0 [
                push(used_files, upath):
                result = result + expand_uses(strip_start(readfile(resolve_use_path(upath)))) + "\n":
            ]
            skip:
        ]
        i = i + 1:
    ]
    result = result + sub(src, seg, n):
    give result:
]

// ---- string interpolation helpers ----
fn has_interp(text s) -> int [
    let int i = 0: let int n = len(s):
    loop while i + 1 < n [
        when s{i} == "$" and s{i + 1} == "{" [ give 1: ]
        i = i + 1:
    ]
    give 0:
]

fn find_dot_s(text s) -> int [
    let int i = 0:
    loop while i < len(s) [
        when s{i} == "." [ give i: ]
        i = i + 1:
    ]
    give -1:
]

fn gen_interp(text s) -> int [
    let int n = len(s): let int i = 0: let int first = 1:
    loop while i < n [
        let int seg_s = i:
        loop while i < n [
            let int hit = 0:
            when i + 1 < n and s{i} == "$" and s{i + 1} == "{" [ hit = 1: ]
            when hit == 1 [ stop: ]
            i = i + 1:
        ]
        let text seg = sub(s, seg_s, i):
        when len(seg) > 0 [
            emit("STR " + esc(seg)):
            when first == 0 [ emit("BIN +"): ]
            first = 0:
        ]
        when i >= n [ stop: ]
        i = i + 2:  // skip "${"
        let int expr_s = i:
        loop while i < n and s{i} != "}" [ i = i + 1: ]
        let text expr = sub(s, expr_s, i):
        i = i + 1:  // skip "}"
        // Re-lex `expr` as its own independent token stream and run it through
        // the real expression parser, so ${a + b}, ${f(x)}, ${obj.field} etc.
        // all work exactly like any other expression (not just a bare LOAD).
        let list saved_tk = tk: let list saved_tv = tv:
        let int saved_pos = pos: let int saved_ntok = ntok:
        tk = {"~"}: tv = {"~"}:
        lex_append(expr):
        ntok = len(tk): pos = 1:
        gen_expr():
        tk = saved_tk: tv = saved_tv: pos = saved_pos: ntok = saved_ntok:
        emit("TOSTR"):
        when first == 0 [ emit("BIN +"): ]
        first = 0:
    ]
    give 0:
]

// ---- token access ----
fn kind() -> text [
    when pos >= ntok [ give "eof": ]
    give tk{pos}:
]

fn val() -> text [
    when pos >= ntok [ give "": ]
    give tv{pos}:
]

fn val2() -> text [
    when pos + 1 >= ntok [ give "": ]
    give tv{pos + 1}:
]

fn adv() -> int [
    pos = pos + 1:
    give 0:
]

// ---- label helpers ----
fn newlab() -> int [
    let int id = nlabs:
    nlabs = nlabs + 1:
    give id:
]

fn lref(int id) -> text [
    give ".L" + totext(id):
]

fn emit(text instr) -> int [
    iglog(instr):
    give 0:
]

fn is_rec(text name) -> int [
    loop r in rec_names [ when r == name [ give 1: ] ]
    give 0:
]

fn is_enum(text name) -> int [
    loop e in enum_n [ when e == name [ give 1: ] ]
    give 0:
]

fn enum_vidx(text ename, text vname) -> int [
    let int idx = 0:
    let int i = 1:
    loop while i < len(enum_var_en) [
        when enum_var_en{i} == ename [
            when enum_var_vn{i} == vname [ give idx: ]
            idx = idx + 1:
        ]
        i = i + 1:
    ]
    give 0:
]

fn vt_set(text name, text typ) -> int [
    push(var_n, name): push(var_t, typ): give 0:
]

fn vt_get(text name) -> text [
    let int i = len(var_n) - 1:
    loop while i >= 0 [
        when var_n{i} == name [ give var_t{i}: ]
        i = i - 1:
    ]
    give "~":
]

fn emitlab(int id) -> int [
    iglog(".L" + totext(id)):
    give 0:
]

// ---- loop stack ----
fn loop_push(int blabel, int clabel) -> int [
    push(brk_labs, blabel):
    push(cnt_labs, clabel):
    push(loop_try_lv, try_depth):
    give 0:
]

fn loop_pop() -> int [
    pop(brk_labs):
    pop(cnt_labs):
    pop(loop_try_lv):
    give 0:
]

fn cur_brk() -> int [ give brk_labs{len(brk_labs) - 1}: ]
fn cur_cnt() -> int [ give cnt_labs{len(cnt_labs) - 1}: ]
fn cur_loop_try_lv() -> int [ give loop_try_lv{len(loop_try_lv) - 1}: ]

// Emit N TRYPOP calls, unwinding N enclosing try-blocks before a jump/return escapes them.
fn emit_trypops(int n) -> int [
    let int i = 0:
    loop while i < n [ emit("TRYPOP"): i = i + 1: ]
    give 0:
]

// ---- expect helpers ----
fn expect_s(text v) -> int [
    when kind() == "sym" and val() == v [ adv(): give 0: ]
    iglog.err("irgen: expected '" + v + "' at pos", pos, "got", val()):
    give 0:
]

fn expect_k(text v) -> int [
    when kind() == "kw" and val() == v [ adv(): give 0: ]
    iglog.err("irgen: expected kw '" + v + "' at pos", pos, "got", val()):
    give 0:
]

// ---- expression code gen ----
fn gen_expr() -> int [
    gen_or():
    give 0:
]

fn gen_arglist() -> int [
    let int argc = 0:
    when kind() != "sym" or val() != ")" [
        gen_expr():
        argc = argc + 1:
        loop while kind() == "sym" and val() == "," [
            adv():
            gen_expr():
            argc = argc + 1:
        ]
    ]
    expect_s(")"):
    give argc:
]

fn gen_primary() -> int [
    let text k = kind():
    let text v = val():

    when k == "num" [
        adv():
        when find_dot_s(v) >= 0 [ emit("CONSTF " + v): give 0: ]
        emit("CONST " + v): give 0:
    ]
    when k == "str" [
        adv():
        when has_interp(v) == 0 [ emit("STR " + esc(v)): give 0: ]
        gen_interp(v): give 0:
    ]
    when k == "kw" and v == "true"  [ adv(): emit("CONST true"): give 0: ]
    when k == "kw" and v == "false" [ adv(): emit("CONST false"): give 0: ]

    when k == "sym" and v == "(" [
        adv(): gen_expr(): expect_s(")"): give 0:
    ]

    when k == "sym" and v == "{" [
        adv():
        let int n = 0:
        let int is_map = 0:
        when kind() != "sym" or val() != "}" [
            gen_expr():
            n = n + 1:
            when kind() == "sym" and val() == "->" [
                adv(): gen_expr(): is_map = 1:
            ]
            loop while kind() == "sym" and val() == "," [
                adv():
                gen_expr():
                n = n + 1:
                when kind() == "sym" and val() == "->" [ adv(): gen_expr(): ]
            ]
        ]
        expect_s("}"):
        when is_map == 1 [ emit("MAP " + totext(n)): ]
        else              [ emit("LIST " + totext(n)): ]
        give 0:
    ]

    when k == "kw" and v == "iglog" [
        adv():
        let text lvl = "info":
        when kind() == "sym" and val() == "." [ adv(): lvl = val(): adv(): ]
        expect_s("("):
        let int argc = gen_arglist():
        emit("LOG " + lvl + " " + totext(argc)):
        give 0:
    ]

    when k == "id" [
        adv():
        when is_enum(v) == 1 [
            expect_s("."):
            let text vname = val(): adv():
            emit("CONST " + totext(enum_vidx(v, vname))):
            give 0:
        ]
        when kind() == "sym" and val() == "(" [
            adv():
            let int argc = gen_arglist():
            when is_rec(v) == 1 [ emit("NEW " + v): give 0: ]
            emit("CALL " + v + " " + totext(argc)):
            give 0:
        ]
        when kind() == "sym" and val() == "." [
            adv():
            let text fname = val(): adv():
            emit("LOAD " + v):
            emit("FGET " + vt_get(v) + " " + fname):
            give 0:
        ]
        emit("LOAD " + v):
        give 0:
    ]

    iglog.err("irgen: unexpected '" + v + "' (kind=" + k + ") at pos", pos):
    adv():
    give 0:
]

fn gen_postfix() -> int [
    gen_primary():
    loop while kind() == "sym" and val() == "{" [
        adv(): gen_expr(): expect_s("}"): emit("INDEX"):
    ]
    give 0:
]

fn gen_unary() -> int [
    when kind() == "sym" and val() == "-" [
        adv(): gen_unary(): emit("NEG"): give 0:
    ]
    gen_postfix(): give 0:
]

fn gen_mul() -> int [
    gen_unary():
    loop while kind() == "sym" and (val() == "*" or val() == "/" or val() == "%") [
        let text op = val(): adv(): gen_unary(): emit("BIN " + op):
    ]
    give 0:
]

fn gen_add() -> int [
    gen_mul():
    loop while kind() == "sym" and (val() == "+" or val() == "-") [
        let text op = val(): adv(): gen_mul(): emit("BIN " + op):
    ]
    give 0:
]

fn gen_cmp() -> int [
    gen_add():
    loop while kind() == "sym" and (val() == "==" or val() == "!=" or val() == "<" or val() == ">" or val() == "<=" or val() == ">=") [
        let text op = val(): adv(): gen_add(): emit("BIN " + op):
    ]
    give 0:
]

fn gen_not() -> int [
    when kind() == "kw" and val() == "not" [
        adv(): gen_not(): emit("NOT"): give 0:
    ]
    gen_cmp(): give 0:
]

fn gen_and() -> int [
    gen_not():
    loop while kind() == "kw" and val() == "and" [
        adv():
        let int lbl = newlab():
        emit("DUP"):
        emit("JF " + lref(lbl)):
        emit("POP"):
        gen_not():
        emitlab(lbl):
        emit("BOOL"):
    ]
    give 0:
]

fn gen_or() -> int [
    gen_and():
    loop while kind() == "kw" and val() == "or" and val2() != "[" [
        adv():
        let int lbl = newlab():
        emit("DUP"):
        emit("JT " + lref(lbl)):
        emit("POP"):
        gen_and():
        emitlab(lbl):
        emit("BOOL"):
    ]
    give 0:
]

// ---- statement and block code gen ----
fn gen_stmt() -> int [
    let text k = kind():
    let text v = val():

    when k == "kw" and v == "let" [
        adv():
        let text decl_type = val(): adv():
        let text decl_name = val(): adv():
        vt_set(decl_name, decl_type):
        when kind() == "sym" and val() == "=" [
            adv(): gen_expr(): emit("DECL " + decl_type + " " + decl_name + " 1"):
        ]
        else [
            when decl_type == "list" [ emit("LIST 0"): ]
            or decl_type == "map"    [ emit("MAP 0"): ]
            or decl_type == "text"   [ emit("STR "): ]
            else                     [ emit("CONST 0"): ]
            emit("DECL " + decl_type + " " + decl_name + " 0"):
        ]
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "fix" [
        adv():
        let text fix_name = val(): adv():
        expect_s("="):
        gen_expr():
        emit("FIX " + fix_name):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "give" [
        adv(): gen_expr(): emit_trypops(try_depth): emit("RET"): expect_s(":"): give 0:
    ]

    when k == "kw" and v == "stop" [
        adv():
        emit_trypops(try_depth - cur_loop_try_lv()):
        emit("JMP " + lref(cur_brk())):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "skip" [
        adv():
        emit_trypops(try_depth - cur_loop_try_lv()):
        emit("JMP " + lref(cur_cnt())):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "iglog" [
        adv():
        let text lvl = "info":
        when kind() == "sym" and val() == "." [ adv(): lvl = val(): adv(): ]
        expect_s("("):
        let int argc = gen_arglist():
        emit("LOG " + lvl + " " + totext(argc)):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "loop" [
        adv():
        when kind() == "kw" and val() == "while" [
            adv():
            let int lbl_top = newlab():
            let int lbl_end = newlab():
            emitlab(lbl_top):
            gen_expr():
            emit("JF " + lref(lbl_end)):
            loop_push(lbl_end, lbl_top):
            gen_block():
            loop_pop():
            emit("JMP " + lref(lbl_top)):
            emitlab(lbl_end):
            give 0:
        ]
        when kind() == "id" and val2() == "in" [
            let text lv = val(): adv(): adv():
            gen_expr():
            when kind() == "kw" and val() == "to" [
                adv():
                gen_expr():
                when kind() == "kw" and val() == "step" [ adv(): gen_expr(): ]
                else [ emit("CONST none"): ]
                emit("RANGE"):
            ]
            else [
                emit("ITER"):
            ]
            let int lbl_inext = newlab():
            let int lbl_ipop  = newlab():
            let int lbl_end   = newlab():
            emitlab(lbl_inext):
            emit("INEXT " + lv + " " + lref(lbl_end)):
            loop_push(lbl_ipop, lbl_inext):
            gen_block():
            loop_pop():
            emit("JMP " + lref(lbl_inext)):
            emitlab(lbl_ipop):
            emit("IPOP"):
            emitlab(lbl_end):
            give 0:
        ]
        // loop count N [block]
        emit("CONST 1"):
        gen_expr():
        emit("CONST 1"):
        emit("RANGE"):
        let int lbl_inext = newlab():
        let int lbl_ipop  = newlab():
        let int lbl_end   = newlab():
        emitlab(lbl_inext):
        emit("INEXT ~ " + lref(lbl_end)):
        loop_push(lbl_ipop, lbl_inext):
        gen_block():
        loop_pop():
        emit("JMP " + lref(lbl_inext)):
        emitlab(lbl_ipop):
        emit("IPOP"):
        emitlab(lbl_end):
        give 0:
    ]

    when k == "kw" and v == "try" [
        adv():
        let int lbl_catch = newlab():
        let int lbl_end   = newlab():
        emit("TRYPUSH " + lref(lbl_catch)):
        try_depth = try_depth + 1:
        gen_block():
        try_depth = try_depth - 1:
        emit("TRYPOP"):
        emit("JMP " + lref(lbl_end)):
        emitlab(lbl_catch):
        expect_k("catch"):
        gen_block():
        emitlab(lbl_end):
        give 0:
    ]

    when k == "kw" and v == "spawn" [
        adv():
        let text fname = val(): adv():
        expect_s("("): expect_s(")"):
        emit("SPAWN " + fname):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "yield" [
        adv(): emit("YIELD"): expect_s(":"): give 0:
    ]

    when k == "kw" and v == "when" [
        adv():
        let int lbl_end = newlab():
        loop while true [
            let int lbl_next = newlab():
            gen_expr():
            emit("JF " + lref(lbl_next)):
            gen_block():
            emit("JMP " + lref(lbl_end)):
            emitlab(lbl_next):
            when kind() == "kw" and val() == "or" [ adv(): ]
            else [ stop: ]
        ]
        when kind() == "kw" and val() == "else" [ adv(): gen_block(): ]
        emitlab(lbl_end):
        give 0:
    ]

    when k == "kw" and v == "match" [
        adv():
        let text mval = val(): adv():
        expect_s("["):
        let int lbl_end = newlab():
        let int done = 0:
        loop while done == 0 [
            when kind() == "kw" and val() == "else" [ done = 1: stop: ]
            when kind() == "sym" and val() == "]"   [ done = 1: stop: ]
            let int lbl_next = newlab():
            emit("LOAD " + mval):
            gen_primary():
            emit("BIN =="):
            emit("JF " + lref(lbl_next)):
            gen_block():
            emit("JMP " + lref(lbl_end)):
            emitlab(lbl_next):
        ]
        when kind() == "kw" and val() == "else" [ adv(): gen_block(): ]
        expect_s("]"):
        emitlab(lbl_end):
        give 0:
    ]

    // field assignment: p.field = expr:
    when k == "id" and val2() == "." [
        let text pname = v: adv(): adv():
        let text fname = val(): adv():
        when kind() == "sym" and val() == "=" [
            adv():
            emit("LOAD " + pname):
            gen_expr():
            emit("FSET " + vt_get(pname) + " " + fname):
            expect_s(":"):
            give 0:
        ]
        emit("LOAD " + pname):
        emit("FGET " + vt_get(pname) + " " + fname):
        emit("POP"):
        expect_s(":"):
        give 0:
    ]

    // simple assignment: name = expr:
    when k == "id" and val2() == "=" [
        let text aname = v: adv(): adv():
        gen_expr():
        emit("STORE " + aname):
        expect_s(":"):
        give 0:
    ]

    // index-assign: name{expr} = rhs:  (and bare name{expr}: as statement)
    when k == "id" and val2() == "{" [
        emit("LOAD " + v): adv():
        expect_s("{"):
        gen_expr():
        expect_s("}"):
        when kind() == "sym" and val() == "=" [
            adv(): gen_expr(): emit("SETIDX"): expect_s(":"): give 0:
        ]
        emit("INDEX"):
        emit("POP"):
        expect_s(":"):
        give 0:
    ]

    // expression statement (function calls, etc.)
    gen_expr():
    emit("POP"):
    expect_s(":"):
    give 0:
]

fn gen_block() -> int [
    expect_s("["):
    loop while pos < ntok and (kind() != "sym" or val() != "]") [
        gen_stmt():
    ]
    expect_s("]"):
    give 0:
]

fn gen_fn() -> int [
    expect_k("fn"):
    let text fname = val(): adv():
    expect_s("("):
    let list ptypes = {"~"}:
    let list pnames = {"~"}:
    let text ret = "int":
    when kind() != "sym" or val() != ")" [
        loop while true [
            let text pt = val(): adv():
            let text pn = val(): adv():
            push(ptypes, pt): push(pnames, pn):
            vt_set(pn, pt):
            when kind() != "sym" or val() != "," [ stop: ]
            adv():
        ]
    ]
    expect_s(")"):
    when kind() == "sym" and val() == "->" [
        adv(): ret = val(): adv():
    ]
    iglog("fn " + fname + " " + ret):
    let int pi = 1:
    loop while pi < len(ptypes) [
        iglog("param " + ptypes{pi} + " " + pnames{pi}):
        pi = pi + 1:
    ]
    try_depth = 0:
    gen_block():
    emit("RETN"):
    iglog("end"):
    give 0:
]

fn gen_program() -> int [
    loop while pos < ntok [
        when kind() == "kw" and val() == "fn" [ gen_fn(): skip: ]
        when kind() == "kw" and val() == "start" [
            adv():
            iglog("main"):
            try_depth = 0:
            gen_block():
            emit("HALT"):
            iglog("end"):
            skip:
        ]
        when kind() == "kw" and val() == "rec" [
            adv():
            let text rname = val(): adv():
            push(rec_names, rname):
            let int fc = 0:
            let list ftypes = {"~"}:
            let list fnames = {"~"}:
            expect_s("["):
            loop while kind() != "sym" or val() != "]" [
                when kind() == "kw" and val() == "private" [ adv(): ]
                push(ftypes, val()): adv():
                push(fnames, val()): adv():
                expect_s(":"):
                fc = fc + 1:
            ]
            expect_s("]"):
            emit("REC " + rname + " " + totext(fc)):
            let int fi = 1:
            loop while fi < len(ftypes) [
                emit("RFIELD " + ftypes{fi} + " " + fnames{fi}):
                fi = fi + 1:
            ]
            skip:
        ]
        when kind() == "kw" and val() == "use" [
            adv(): adv(): expect_s(":"): skip:
        ]
        when kind() == "kw" and val() == "enum" [
            adv():
            let text ename = val(): adv():
            push(enum_n, ename):
            let int vc = 0:
            expect_s("["):
            loop while kind() != "sym" or val() != "]" [
                let text vname = val(): adv():
                push(enum_var_en, ename):
                push(enum_var_vn, vname):
                enum_var_total = enum_var_total + 1:
                vc = vc + 1:
                expect_s(":"):
            ]
            expect_s("]"):
            emit("ENUM " + ename + " " + totext(vc)):
            let int vsi = len(enum_var_vn) - vc:
            loop vi in 0 to vc - 1 [
                emit("EVARIANT " + enum_var_vn{vsi + vi}):
            ]
            skip:
        ]
        gen_stmt():
    ]
    give 0:
]

// ---- entry: lex the file, then generate IR ----
// Lexes `src`, APPENDING tokens onto the current tk/tv (does not reset them).
// Used both for the top-level file and, via gen_interp(), to re-lex a `${...}`
// interpolation expression as its own independent token stream.
fn lex_append(text src) -> int [
    let int slen = len(src):
    let int p = 0:

    loop while p < slen [
        let text ch = src{p}:

        when ch == " " or ch == "\t" or ch == "\n" or ch == "\r" [
            p = p + 1: skip:
        ]

        when ch == "/" and p + 1 < slen [
            when src{p + 1} == "/" [
                loop while p < slen and src{p} != "\n" [ p = p + 1: ]
                skip:
            ]
        ]

        when isdigit(ch) == 1 [
            let int s = p:
            loop while p < slen [
                when isdigit(src{p}) == 0 and src{p} != "." [ stop: ]
                p = p + 1:
            ]
            push(tk, "num"): push(tv, sub(src, s, p)): skip:
        ]

        when isalpha(ch) == 1 [
            let int s = p:
            loop while p < slen [
                when isalpha(src{p}) == 0 and isdigit(src{p}) == 0 [ stop: ]
                p = p + 1:
            ]
            let text w = sub(src, s, p):
            when iskeyword(w) == 1 [ push(tk, "kw"): ]
            else                   [ push(tk, "id"): ]
            push(tv, w): skip:
        ]

        when ch == "\"" [
            let int s = p + 1:
            p = p + 1:
            loop while p < slen and src{p} != "\"" [
                when src{p} == "\\" [ p = p + 2: skip: ]
                p = p + 1:
            ]
            push(tk, "str"): push(tv, sub(src, s, p)):
            p = p + 1: skip:
        ]

        when p + 1 < slen [
            let text two = ch + src{p + 1}:
            when two == "==" or two == "!=" or two == "<=" or two == ">=" or two == "->" [
                push(tk, "sym"): push(tv, two): p = p + 2: skip:
            ]
        ]

        push(tk, "sym"): push(tv, ch): p = p + 1:
    ]
    give 0:
]

start [
    iglog.err("Ignid file to compile: "):
    let text path = ask(""):
    push(used_files, path):
    let text src = expand_uses(readfile(path)):
    lex_append(src):
    ntok = len(tk):
    pos = 1:
    gen_program():
]
