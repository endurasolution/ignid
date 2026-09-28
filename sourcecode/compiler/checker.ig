// checker.ig — Ignid type checker (self-hosting step 3)
// Reads a .ig source file, lexes it, then type-checks it.

// ---- global token store (sentinel at index 0) ----
let list tk = {"~"}:
let list tv = {"~"}:
let list toff = {0}:
let text g_src = "":
let text g_path = "":
let int ntok = 1:
let int pos = 1:
// line_owner{raw_expanded_line} = the line number WITHIN whichever file owns
// that expanded line; file_owner{raw_expanded_line} = that file's path. Together
// they give an exact (file, line) location for any position in the post-`use`-
// expansion source, at any `use` nesting depth — see expand_uses_c/track_chunk.
let list line_owner = {0}:
let list file_owner = {"~"}:

// character offset -> 1-based RAW line number in the expanded source (counts
// newlines up to `off`; used as an index into line_owner/file_owner, and only
// ever called when reporting an error, so O(n) per call is fine)
fn line_of(int off) -> int [
    let int ln = 1: let int i = 0: let int n = len(g_src):
    when off < n [ n = off: ]
    loop while i < n [
        when g_src{i} == "\n" [ ln = ln + 1: ]
        i = i + 1:
    ]
    give ln:
]

// human-readable "line N" (same file as g_path) or "path:N" (a `use`d file)
// location string for the given character offset.
fn loc_of(int off) -> text [
    let int raw = line_of(off):
    when raw < len(file_owner) [
        let text fp = file_owner{raw}:
        let int rel = line_owner{raw}:
        when fp == g_path [ give "line " + totext(rel): ]
        give fp + ":" + totext(rel):
    ]
    give "line " + totext(raw):
]

// which file's own text owns the given character offset (for encapsulation
// checks — is this field access happening in the same file that declared the
// record?). "" if unknown (shouldn't normally happen).
fn file_of(int off) -> text [
    let int raw = line_of(off):
    when raw < len(file_owner) [ give file_owner{raw}: ]
    give "":
]

// ---- symbol table (flat, most-recent-wins; sentinel at index 0) ----
let list sym_n = {"~"}:
let list sym_t = {"~"}:

// ---- checker state ----
let int errors = 0:
let text cur_ret = "int":

// ---- rec type registry ----
let list rec_n = {"~"}:
let list rec_field_n = {"~"}:
let list rec_field_t = {"~"}:
let list rec_field_private = {0}:
let list rec_owner_file = {"~"}:

fn rec_field_is_private(text rname, text fname) -> int [
    let text key = rname + "." + fname:
    let int i = 1:
    loop while i < len(rec_field_n) [
        when rec_field_n{i} == key [ give rec_field_private{i}: ]
        i = i + 1:
    ]
    give 0:
]

fn rec_owner_of(text rname) -> text [
    let int i = 1:
    loop while i < len(rec_n) [
        when rec_n{i} == rname [ give rec_owner_file{i}: ]
        i = i + 1:
    ]
    give "":
]
let list fnp_owner = {"~"}:
let list fnp_type = {"~"}:

fn get_param_count(text fname) -> int [
    let int i = 1: let int c = 0:
    loop while i < len(fnp_owner) [
        when fnp_owner{i} == fname [ c = c + 1: ]
        i = i + 1:
    ]
    give c:
]

fn get_param_type(text fname, int idx) -> text [
    let int i = 1: let int seen = 0:
    loop while i < len(fnp_owner) [
        when fnp_owner{i} == fname [
            when seen == idx [ give fnp_type{i}: ]
            seen = seen + 1:
        ]
        i = i + 1:
    ]
    give "any":
]

fn check_arg_type(text fname, int idx, text at) -> int [
    when len(fname) == 0 [ give 0: ]
    let int pc = get_param_count(fname):
    when idx >= pc [ give 0: ]
    let text pt = get_param_type(fname, idx):
    when compat(pt, at) == 0 [
        terr("call to " + fname + "(): argument " + totext(idx + 1) + " expects " + pt + " but got " + at):
    ]
    give 0:
]
let list enum_n = {"~"}:
let list used_files_c = {}:

// ---- module expansion (same logic as irgen) ----
fn strip_start_c(text src) -> text [
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

// ---- line-ownership tracking for expand_uses_c (see below) ----
// line_owner{expanded_line_n} = the ORIGINAL line number in the top-level file
// being checked, or 0 if that expanded line actually came from a `use`d file
// (whether that file's own content, or anything IT transitively `use`s).
// This lets error messages report a line number that matches what's actually
// open in the editor, instead of a position in the internally-expanded source.
// stack of file paths currently being expanded; top = whichever file's own
// text is presently being appended (see expand_uses_c/track_chunk)
let list ex_filestack = {"~"}:
fn cur_file() -> text [ give ex_filestack{len(ex_filestack) - 1}: ]

// records, for each newline completed in `chunk`, (cur_file(), curline) into
// file_owner/line_owner — curline is a plain int returned/threaded by the
// caller (Ignid has no reference/out-parameters), so each call site does
// `curline = track_chunk(chunk, curline):`
fn track_chunk(text chunk, int curline) -> int [
    let text fpath = cur_file():
    let int k = 0: let int cn = len(chunk):
    loop while k < cn [
        when chunk{k} == "\n" [
            push(file_owner, fpath):
            push(line_owner, curline):
            curline = curline + 1:
        ]
        k = k + 1:
    ]
    give curline:
]

// A bare `use` filename (no "/" or "\" in it — e.g. `use "std.ig":`) is
// resolved relative to the current working directory first, same as always,
// so a project's own sibling files (`use "utils.ig":` compiled from within
// that project's folder) keep working exactly as before. Only if that lookup
// fails does this fall back to the directory the compiler itself lives in —
// which is where std.ig/ignidweb.ig actually sit once installed — so
// `use "std.ig":` works regardless of which folder you're compiling from.
// A path that already contains a separator is left untouched either way.
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

fn expand_uses_c(text src) -> text [
    // segment-based O(n) expansion: skip string literals/comments to avoid false positives
    let int n = len(src): let int i = 0:
    let text result = "": let int seg = 0:
    let int curline = 1:
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
            let text chunk = sub(src, seg, i):
            curline = track_chunk(chunk, curline):
            result = result + chunk:
            let int ps = i + 5: let int pe = ps:
            loop while pe < n [ when src{pe} == "\"" [ stop: ] pe = pe + 1: ]
            let text upath = sub(src, ps, pe):
            let int sk = pe + 1:
            loop while sk < n [ when src{sk} == ":" [ stop: ] sk = sk + 1: ]
            i = sk + 1: seg = i:
            let int already = 0:
            loop f in used_files_c [ when f == upath [ already = 1: ] ]
            when already == 0 [
                push(used_files_c, upath):
                push(ex_filestack, upath):
                let text inc = expand_uses_c(strip_start_c(readfile(resolve_use_path(upath)))):
                pop(ex_filestack):
                // this "\n" is a synthetic separator, not real content from
                // ANY original file — it still needs a line_owner/file_owner
                // entry to keep those arrays index-aligned with g_src's actual
                // newline count, but must NOT advance the outer file's curline
                // (it doesn't correspond to a newline the outer file actually
                // has). Attribute it to the just-finished used file instead.
                push(file_owner, upath): push(line_owner, 0):
                result = result + inc + "\n":
            ]
            skip:
        ]
        i = i + 1:
    ]
    let text tail = sub(src, seg, n):
    curline = track_chunk(tail, curline):
    result = result + tail:
    give result:
]

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

fn is_rec_type(text t) -> int [
    loop r in rec_n [ when r == t [ give 1: ] ]
    give 0:
]

fn is_enum_type(text t) -> int [
    loop e in enum_n [ when e == t [ give 1: ] ]
    give 0:
]

fn rec_field_type(text rname, text fname) -> text [
    let text key = rname + "." + fname:
    let int i = 1:
    loop while i < len(rec_field_n) [
        when rec_field_n{i} == key [ give rec_field_t{i}: ]
        i = i + 1:
    ]
    give "unknown":
]

fn has_dot(text s) -> int [
    let int i = 0:
    let int n = len(s):
    loop while i < n [
        when s{i} == "." [ give 1: ]
        i = i + 1:
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

// ---- symbol table ----
fn sym_set(text name, text typ) -> int [
    push(sym_n, name):
    push(sym_t, typ):
    give 0:
]

fn sym_get(text name) -> text [
    let int i = len(sym_n) - 1:
    loop while i >= 0 [
        when sym_n{i} == name [ give sym_t{i}: ]
        i = i - 1:
    ]
    give "unknown":
]

// ---- error helpers ----
fn terr(text msg) -> int [
    let int tp = pos:
    when tp >= len(toff) [ tp = len(toff) - 1: ]
    iglog.err("[type error]", loc_of(toff{tp}) + ":", msg, "near", val()):
    errors = errors + 1:
    give 0:
]

fn compat(text want, text got) -> int [
    when want == "any" or got == "any" or want == "var" or got == "var" or want == got [ give 1: ]
    when want == "float" and got == "int" [ give 1: ]
    when (want == "int" or want == "bool") and (got == "int" or got == "bool") [ give 1: ]
    give 0:
]

fn expect_s(text v) -> int [
    when kind() == "sym" and val() == v [ adv(): give 0: ]
    terr("expected '" + v + "'"):
    give 0:
]

fn expect_k(text v) -> int [
    when kind() == "kw" and val() == v [ adv(): give 0: ]
    terr("expected keyword '" + v + "'"):
    give 0:
]

// ---- builtin return types ----
fn builtin_ret(text name) -> text [
    when name == "len" or name == "toint" or name == "ord" or name == "clock" or name == "print" or name == "println" or name == "system" [ give "int": ]
    when name == "tofloat" [ give "float": ]
    when name == "chr" [ give "text": ]
    when name == "totext" or name == "ask" or name == "sub" or name == "readfile" [ give "text": ]
    give "any":
]

// ---- pre-scan: register all fn names + return types before checking ----
fn scan_fns() -> int [
    let int saved = pos:
    pos = 1:
    loop while pos < ntok [
        when kind() == "kw" and val() == "rec" [
            adv():
            let text rname = val():
            let text rfile = file_of(toff{pos}):
            adv():
            push(rec_n, rname):
            push(rec_owner_file, rfile):
            adv():  // skip "["
            loop while pos < ntok and (kind() != "sym" or val() != "]") [
                let int is_priv = 0:
                when kind() == "kw" and val() == "private" [ is_priv = 1: adv(): ]
                let text ftype = val(): adv():
                let text fname = val(): adv():
                push(rec_field_n, rname + "." + fname):
                push(rec_field_t, ftype):
                push(rec_field_private, is_priv):
                adv():  // skip ":"
            ]
            adv():  // skip "]"
            skip:
        ]
        when kind() == "kw" and val() == "enum" [
            adv():
            let text ename = val(): adv():
            push(enum_n, ename):
            adv():  // skip "["
            loop while pos < ntok and (kind() != "sym" or val() != "]") [
                adv(): adv():  // skip variant_name and ":"
            ]
            adv():  // skip "]"
            skip:
        ]
        when kind() == "kw" and val() == "fn" [
            adv():
            let text fname = val():
            adv():
            expect_s("("):
            when kind() != "sym" or val() != ")" [
                let int more = 1:
                loop while more == 1 [
                    let text ptype = val(): adv():
                    adv():  // skip param name
                    push(fnp_owner, fname): push(fnp_type, ptype):
                    when kind() == "sym" and val() == "," [ adv(): ]
                    else [ more = 0: ]
                ]
            ]
            expect_s(")"):
            // now at -> or [
            let text rtype = "int":
            when kind() == "sym" and val() == "->" [
                adv():
                rtype = val():
                adv():
            ]
            sym_set(fname, "fn"):
            sym_set(fname + "(ret)", rtype):
            skip:
        ]
        adv():
    ]
    pos = saved:
    give 0:
]

// ---- argument list (pos already past "(") ----
fn chk_arglist(text fname) -> int [
    let int idx = 0:
    when kind() != "sym" or val() != ")" [
        check_arg_type(fname, idx, chk_expr()):
        idx = idx + 1:
        loop while kind() == "sym" and val() == "," [
            adv():
            check_arg_type(fname, idx, chk_expr()):
            idx = idx + 1:
        ]
    ]
    expect_s(")"):
    give 0:
]

// ---- expression type inference ----
fn chk_primary() -> text [
    let text k = kind():
    let text v = val():

    when k == "num" [
        adv():
        when has_dot(v) == 1 [ give "float": ]
        give "int":
    ]

    when k == "str" [ adv(): give "text": ]

    when k == "kw" and v == "true"  [ adv(): give "bool": ]
    when k == "kw" and v == "false" [ adv(): give "bool": ]

    when k == "sym" and v == "(" [
        adv():
        let text t = chk_expr():
        expect_s(")"):
        give t:
    ]

    when k == "sym" and v == "{" [
        adv():
        let text rt = "list":
        when kind() != "sym" or val() != "}" [
            chk_expr():
            when kind() == "sym" and val() == "->" [
                adv():
                chk_expr():
                rt = "map":
            ]
            loop while kind() == "sym" and val() == "," [
                adv():
                chk_expr():
                when kind() == "sym" and val() == "->" [
                    adv():
                    chk_expr():
                    rt = "map":
                ]
            ]
        ]
        expect_s("}"):
        give rt:
    ]

    when k == "kw" and v == "iglog" [
        adv():
        when kind() == "sym" and val() == "." [ adv(): adv(): ]
        expect_s("("):
        chk_arglist(""):
        give "int":
    ]

    when k == "id" [
        let text sym_type = sym_get(v):
        adv():
        when is_enum_type(v) == 1 [
            when kind() == "sym" and val() == "." [ adv(): adv(): ]
            give v:
        ]
        when kind() == "sym" and val() == "(" [
            when is_rec_type(v) == 1 [
                adv(): chk_arglist(""): give v:
            ]
            let text ret = sym_get(v + "(ret)"):
            when ret == "unknown" [ ret = builtin_ret(v): ]
            adv():
            chk_arglist(v):
            give ret:
        ]
        when sym_type == "unknown" [
            terr("undeclared identifier: " + v):
            give "any":
        ]
        give sym_type:
    ]

    terr("unexpected token '" + v + "' (kind=" + k + ")"):
    adv():
    give "any":
]

fn chk_postfix() -> text [
    let text t = chk_primary():
    loop while kind() == "sym" and (val() == "{" or val() == ".") [
        when val() == "{" [
            adv(): chk_expr(): expect_s("}"): t = "any":
        ]
        or val() == "." [
            adv():
            let text fname = val():
            let int facc_off = toff{pos}:
            adv():
            when rec_field_is_private(t, fname) == 1 [
                when file_of(facc_off) != rec_owner_of(t) [
                    terr("field '" + fname + "' of " + t + " is private (declared in " + rec_owner_of(t) + ")"):
                ]
            ]
            t = rec_field_type(t, fname):
        ]
    ]
    give t:
]

fn chk_unary() -> text [
    when kind() == "sym" and val() == "-" [
        adv():
        give chk_unary():
    ]
    give chk_postfix():
]

fn chk_mul() -> text [
    let text t = chk_unary():
    loop while kind() == "sym" and (val() == "*" or val() == "/" or val() == "%") [
        adv():
        let text r = chk_unary():
        when t == "float" or r == "float" [ t = "float": ]
        else [ t = "int": ]
    ]
    give t:
]

fn chk_add() -> text [
    let text t = chk_mul():
    loop while kind() == "sym" and (val() == "+" or val() == "-") [
        let text op = val():
        adv():
        let text r = chk_mul():
        when op == "+" and (t == "text" or r == "text") [ t = "text": ]
        or t == "float" or r == "float" [ t = "float": ]
        else [ t = "int": ]
    ]
    give t:
]

fn chk_cmp() -> text [
    let text t = chk_add():
    loop while kind() == "sym" and (val() == "==" or val() == "!=" or val() == "<" or val() == ">" or val() == "<=" or val() == ">=") [
        adv():
        chk_add():
        t = "bool":
    ]
    give t:
]

fn chk_not() -> text [
    when kind() == "kw" and val() == "not" [
        adv():
        chk_not():
        give "bool":
    ]
    give chk_cmp():
]

fn chk_and() -> text [
    let text t = chk_not():
    loop while kind() == "kw" and val() == "and" [
        adv():
        chk_not():
        t = "bool":
    ]
    give t:
]

fn chk_or() -> text [
    let text t = chk_and():
    loop while kind() == "kw" and val() == "or" and val2() != "[" [
        adv():
        chk_and():
        t = "bool":
    ]
    give t:
]

fn chk_expr() -> text [
    give chk_or():
]

// ---- block and statement checking ----
fn chk_block() -> int [
    expect_s("["):
    loop while pos < ntok and (kind() != "sym" or val() != "]") [
        chk_stmt():
    ]
    expect_s("]"):
    give 0:
]

fn chk_stmt() -> int [
    let text k = kind():
    let text v = val():

    when k == "kw" and v == "let" [
        adv():
        let text decl_type = val(): adv():
        let text decl_name = val(): adv():
        sym_set(decl_name, decl_type):
        when kind() == "sym" and val() == "=" [
            adv():
            let text et = chk_expr():
            when compat(decl_type, et) == 0 [
                terr("let " + decl_name + ": declared " + decl_type + " but initializer is " + et):
            ]
        ]
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "fix" [
        adv():
        let text fix_name = val(): adv():
        expect_s("="):
        let text et = chk_expr():
        sym_set(fix_name, et):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "give" [
        adv():
        let text et = chk_expr():
        when compat(cur_ret, et) == 0 [
            terr("give: function returns " + cur_ret + " but expression is " + et):
        ]
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "stop" [ adv(): expect_s(":"): give 0: ]
    when k == "kw" and v == "skip" [ adv(): expect_s(":"): give 0: ]

    when k == "kw" and v == "iglog" [
        adv():
        when kind() == "sym" and val() == "." [ adv(): adv(): ]
        expect_s("("):
        chk_arglist(""):
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "loop" [
        adv():
        when kind() == "kw" and val() == "while" [
            adv():
            chk_expr():
            chk_block():
            give 0:
        ]
        when kind() == "id" and val2() == "in" [
            let text lv = val(): adv(): adv():
            sym_set(lv, "int"):
            let text et = chk_expr():
            when kind() == "kw" and val() == "to" [
                adv():
                chk_expr():
                when kind() == "kw" and val() == "step" [ adv(): chk_expr(): ]
            ]
            when et == "list" or et == "map" or et == "any" [
                sym_set(lv, "any"):
            ]
            chk_block():
            give 0:
        ]
        chk_expr():
        chk_block():
        give 0:
    ]

    when k == "kw" and v == "try" [
        adv():
        chk_block():
        expect_k("catch"):
        chk_block():
        give 0:
    ]

    when k == "kw" and v == "spawn" [
        adv():
        let text fname = val(): adv():
        expect_s("("): expect_s(")"):
        when sym_get(fname) != "fn" [
            terr("spawn: '" + fname + "' is not a declared function"):
        ]
        when get_param_count(fname) != 0 [
            terr("spawn: " + fname + "() must take zero arguments"):
        ]
        expect_s(":"):
        give 0:
    ]

    when k == "kw" and v == "yield" [
        adv(): expect_s(":"): give 0:
    ]

    when k == "kw" and v == "when" [
        adv():
        chk_expr():
        chk_block():
        loop while kind() == "kw" and val() == "or" [
            adv():
            chk_expr():
            chk_block():
        ]
        when kind() == "kw" and val() == "else" [ adv(): chk_block(): ]
        give 0:
    ]

    when k == "kw" and v == "match" [
        adv(): adv():  // consume "match" and the match variable
        expect_s("["):
        let int done = 0:
        loop while done == 0 [
            when kind() == "kw" and val() == "else" [ done = 1: stop: ]
            when kind() == "sym" and val() == "]"   [ done = 1: stop: ]
            chk_primary():
            chk_block():
        ]
        when kind() == "kw" and val() == "else" [ adv(): chk_block(): ]
        expect_s("]"):
        give 0:
    ]

    // simple assignment: name = expr:
    when k == "id" and val2() == "=" [
        let text aname = v: adv(): adv():
        let text decl = sym_get(aname):
        let text et = chk_expr():
        when decl != "unknown" and compat(decl, et) == 0 [
            terr(aname + " = " + et + " but variable declared as " + decl):
        ]
        when decl == "unknown" [ sym_set(aname, et): ]
        expect_s(":"):
        give 0:
    ]

    // expression statement (also handles index-assign: expr{i} = expr:)
    chk_expr():
    when kind() == "sym" and val() == "=" [
        adv():
        chk_expr():
    ]
    expect_s(":"):
    give 0:
]

fn chk_fn() -> int [
    expect_k("fn"):
    let text fname = val(): adv():
    expect_s("("):
    when kind() != "sym" or val() != ")" [
        loop while true [
            let text pt = val(): adv():
            let text pn = val(): adv():
            sym_set(pn, pt):
            when kind() != "sym" or val() != "," [ stop: ]
            adv():
        ]
    ]
    expect_s(")"):
    let text rtype = "int":
    when kind() == "sym" and val() == "->" [
        adv():
        rtype = val():
        adv():
    ]
    let text saved = cur_ret:
    cur_ret = rtype:
    chk_block():
    cur_ret = saved:
    give 0:
]

fn chk_program() -> int [
    loop while pos < ntok [
        when kind() == "kw" and val() == "fn" [ chk_fn(): skip: ]
        when kind() == "kw" and val() == "rec" [
            adv(): adv(): adv():  // consume "rec", name, "["
            loop while pos < ntok and (kind() != "sym" or val() != "]") [
                when kind() == "kw" and val() == "private" [ adv(): ]
                adv(): adv(): adv():  // consume type, name, ":"
            ]
            adv():  // consume "]"
            skip:
        ]
        when kind() == "kw" and val() == "use" [
            adv(): adv(): adv():  // consume "use", path, ":"
            skip:
        ]
        when kind() == "kw" and val() == "enum" [
            adv(): adv(): adv():  // consume "enum", name, "["
            loop while pos < ntok and (kind() != "sym" or val() != "]") [
                adv(): adv():  // consume variant_name, ":"
            ]
            adv():  // consume "]"
            skip:
        ]
        when kind() == "kw" and val() == "use" [
            adv(): adv(): adv():  // consume "use", path, ":"
            skip:
        ]
        when kind() == "kw" and val() == "start" [
            adv():
            let text saved = cur_ret:
            cur_ret = "int":
            chk_block():
            cur_ret = saved:
            skip:
        ]
        chk_stmt():
    ]
    give 0:
]

// ---- entry: lex the file, then check ----
start [
    let text path = ask("Ignid file to check: "):
    g_path = path:
    push(used_files_c, path):
    push(ex_filestack, path):
    let text src = expand_uses_c(readfile(path)):
    g_src = src:
    let int slen = len(src):
    let int p = 0:

    loop while p < slen [
        let text ch = src{p}:

        when ch == " " or ch == "\t" or ch == "\n" or ch == "\r" [
            p = p + 1:
            skip:
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
            push(tk, "num"):
            push(tv, sub(src, s, p)):
            push(toff, s):
            skip:
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
            push(tv, w):
            push(toff, s):
            skip:
        ]

        when ch == "\"" [
            let int s = p + 1:
            let int soff = p:
            p = p + 1:
            loop while p < slen and src{p} != "\"" [
                when src{p} == "\\" [
                    p = p + 2:
                    skip:
                ]
                p = p + 1:
            ]
            push(tk, "str"):
            push(tv, sub(src, s, p)):
            push(toff, soff):
            p = p + 1:
            skip:
        ]

        when p + 1 < slen [
            let text two = ch + src{p + 1}:
            when two == "==" or two == "!=" or two == "<=" or two == ">=" or two == "->" [
                push(tk, "sym"):
                push(tv, two):
                push(toff, p):
                p = p + 2:
                skip:
            ]
        ]

        push(tk, "sym"):
        push(tv, ch):
        push(toff, p):
        p = p + 1:
    ]

    ntok = len(tk):
    pos = 1:
    iglog("--- {ntok} tokens, checking ---"):

    // register builtins
    sym_set("len",       "fn"): sym_set("len(ret)",       "int"):
    sym_set("toint",     "fn"): sym_set("toint(ret)",     "int"):
    sym_set("tofloat",   "fn"): sym_set("tofloat(ret)",   "float"):
    sym_set("int_to_float", "fn"): sym_set("int_to_float(ret)", "float"):
    sym_set("float_to_int", "fn"): sym_set("float_to_int(ret)", "int"):
    sym_set("totext",    "fn"): sym_set("totext(ret)",     "text"):
    sym_set("ask",       "fn"): sym_set("ask(ret)",        "text"):
    sym_set("sub",       "fn"): sym_set("sub(ret)",        "text"):
    sym_set("readfile",  "fn"): sym_set("readfile(ret)",   "text"):
    sym_set("writefile", "fn"): sym_set("writefile(ret)",  "int"):
    sym_set("file_open",       "fn"): sym_set("file_open(ret)",       "int"):
    sym_set("file_read_chunk", "fn"): sym_set("file_read_chunk(ret)", "text"):
    sym_set("file_eof",        "fn"): sym_set("file_eof(ret)",        "int"):
    sym_set("file_close",      "fn"): sym_set("file_close(ret)",      "int"):
    sym_set("push",      "fn"): sym_set("push(ret)",       "int"):
    sym_set("quit",      "fn"): sym_set("quit(ret)",       "int"):
    sym_set("ord",       "fn"): sym_set("ord(ret)",        "int"):
    sym_set("chr",       "fn"): sym_set("chr(ret)",        "text"):
    sym_set("clock",     "fn"): sym_set("clock(ret)",      "int"):
    sym_set("argc",      "fn"): sym_set("argc(ret)",       "int"):
    sym_set("argv",      "fn"): sym_set("argv(ret)",       "text"):
    sym_set("lasterror", "fn"): sym_set("lasterror(ret)",  "text"):
    sym_set("sock_listen", "fn"): sym_set("sock_listen(ret)", "int"):
    sym_set("sock_accept", "fn"): sym_set("sock_accept(ret)", "int"):
    sym_set("sock_recv",   "fn"): sym_set("sock_recv(ret)",   "text"):
    sym_set("sock_send",   "fn"): sym_set("sock_send(ret)",   "int"):
    sym_set("sock_close",  "fn"): sym_set("sock_close(ret)",  "int"):
    sym_set("map_new",      "fn"): sym_set("map_new(ret)",      "map"):
    sym_set("map_set",      "fn"): sym_set("map_set(ret)",      "map"):
    sym_set("map_get_text", "fn"): sym_set("map_get_text(ret)", "text"):
    sym_set("map_get_int",  "fn"): sym_set("map_get_int(ret)",  "int"):
    sym_set("map_get_float","fn"): sym_set("map_get_float(ret)","float"):
    sym_set("map_has",      "fn"): sym_set("map_has(ret)",      "int"):
    sym_set("map_keys",     "fn"): sym_set("map_keys(ret)",     "list"):
    sym_set("print",     "fn"): sym_set("print(ret)",      "int"):
    sym_set("println",   "fn"): sym_set("println(ret)",    "int"):
    sym_set("printout",  "fn"): sym_set("printout(ret)",   "int"):
    sym_set("run_coroutines", "fn"): sym_set("run_coroutines(ret)", "int"):
    sym_set("system",    "fn"): sym_set("system(ret)",     "int"):
    sym_set("getenv",    "fn"): sym_set("getenv(ret)",     "text"):
    sym_set("exedir",    "fn"): sym_set("exedir(ret)",     "text"):

    // pre-scan all user-defined function signatures
    scan_fns():

    chk_program():

    iglog("--- check done:", errors, "error(s) ---"):
    when errors > 0 [ quit(1): ]
]
