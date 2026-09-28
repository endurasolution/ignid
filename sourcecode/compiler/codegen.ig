// codegen.ig — Ignid IR -> NASM x86-64 code generator (self-hosting step 6)
// Reads label-based IR (irgen.ig|opt.ig output) and emits NASM assembly.

// ---- globals (must be before all functions so codegen emits init in user_main) ----
let list str_vals = {"~"}:
let int nstr = 0:
let list dbl_vals = {"~"}:
let int ndbl = 0:
let list lines = {"~"}:
let list fn_n = {"~"}:
let list fn_r = {"~"}:
let list gvar_n  = {"~"}:
let list gtype_n = {"~"}:
let list gtype_t = {"~"}:
let list slot_n = {"~"}:
let int nslots = 0:
let list vtype_n = {"~"}:
let list vtype_t = {"~"}:
let list ts = {"~"}:
let int cg_lab = 0:
let int cur_fn_is_coro = 0:
let list ik = {"~"}:
let list ie = {"~"}:
let int cur_d = 0:
let list rec_n    = {"~"}:
let list rfield_rn = {"~"}:
let list rfield_fn = {"~"}:
let list rfield_ft = {"~"}:
let text cur_rec   = "":
let list enum_n_cg = {"~"}:

// ---- string helpers ----
fn starts_with(text s, text pfx) -> int [
    let int plen = len(pfx):
    when len(s) < plen [ give 0: ]
    when sub(s, 0, plen) == pfx [ give 1: ]
    give 0:
]

// ---- IR line word extraction ----
fn w0(text line) -> text [
    let int i = 0: let int n = len(line):
    loop while i < n and line{i} != " " [ i = i + 1: ]
    give sub(line, 0, i):
]

fn skip1(text line) -> int [
    let int i = 0: let int n = len(line):
    loop while i < n and line{i} != " " [ i = i + 1: ]
    when i < n [ i = i + 1: ]
    give i:
]

fn skip2(text line) -> int [
    let int p = skip1(line): let int n = len(line):
    loop while p < n and line{p} != " " [ p = p + 1: ]
    when p < n [ p = p + 1: ]
    give p:
]

fn wordp(text line, int p) -> text [
    let int i = p: let int n = len(line):
    loop while i < n and line{i} != " " [ i = i + 1: ]
    give sub(line, p, i):
]

fn w1(text line) -> text [ give wordp(line, skip1(line)): ]
fn w2(text line) -> text [ give wordp(line, skip2(line)): ]
fn rest(text line) -> text [ give sub(line, skip1(line), len(line)): ]

// ---- IR label -> NASM label ----
fn lname(text ir_label) -> text [
    give "ig_" + sub(ir_label, 1, len(ir_label)):
]

// ---- type helpers ----
fn is_text_t(text t) -> int [ when t == "s" [ give 1: ] give 0: ]
fn is_float_t(text t) -> int [ when t == "f" [ give 1: ] give 0: ]
fn is_list_t(text t) -> int [
    when t == "l" or t == "ls" [ give 1: ] give 0:
]
fn elem_t(text lt) -> text [ when lt == "ls" [ give "s": ] give "i": ]
fn fnret_tag(text ret) -> text [
    when ret == "text" or ret == "s" [ give "s": ]
    when ret == "list" or ret == "l" [ give "ls": ]
    when ret == "float" or ret == "f" [ give "f": ]
    give "i":
]

fn ir_to_tag(text t) -> text [
    when t == "int" or t == "bool" [ give "i": ]
    when t == "text" [ give "s": ]
    when t == "list" [ give "l": ]
    when t == "float" [ give "f": ]
    give t:
]

fn rec_size(text rname) -> int [
    let int count = 0: let int i = 1:
    loop while i < len(rfield_rn) [
        when rfield_rn{i} == rname [ count = count + 1: ]
        i = i + 1:
    ]
    give count * 8:
]

fn field_offset(text rname, text fname) -> int [
    let int off = 0: let int i = 1:
    loop while i < len(rfield_rn) [
        when rfield_rn{i} == rname [
            when rfield_fn{i} == fname [ give off: ]
            off = off + 8:
        ]
        i = i + 1:
    ]
    give 0:
]

fn rfield_ft_get(text rname, text fname) -> text [
    let int i = 1:
    loop while i < len(rfield_rn) [
        when rfield_rn{i} == rname and rfield_fn{i} == fname [ give rfield_ft{i}: ]
        i = i + 1:
    ]
    give "int":
]

// ---- string constant table ----
fn sref(text sv) -> text [
    let int i = 1:
    loop while i < len(str_vals) [
        when str_vals{i} == sv [ give "str_" + totext(i - 1): ]
        i = i + 1:
    ]
    push(str_vals, sv):
    let int lab = nstr:
    nstr = nstr + 1:
    give "str_" + totext(lab):
]

// ---- float constant table ----
fn dref(text dv) -> text [
    let int i = 1:
    loop while i < len(dbl_vals) [
        when dbl_vals{i} == dv [ give "dbl_" + totext(i - 1): ]
        i = i + 1:
    ]
    push(dbl_vals, dv):
    let int lab = ndbl:
    ndbl = ndbl + 1:
    give "dbl_" + totext(lab):
]

// Convert escaped IR string to NASM db operand list (e.g. "hello",10,"world",0)
fn str_to_db(text s) -> text [
    let text out = "":
    let int i = 0: let int n = len(s): let int in_q = 0:
    loop while i < n [
        let text c = s{i}:
        when c == "\\" and i + 1 < n and s{i + 1} == "\\" [
            // IR uses double-backslash escapes: \\n→10, \\r→13, \\t→9, \\\\→92
            when in_q == 1 [ out = out + "\"": in_q = 0: ]
            when len(out) > 0 [ out = out + ",": ]
            when i + 2 < n [
                let text nc = s{i + 2}:
                when nc == "n"  [ out = out + "10":  i = i + 3: skip: ]
                or   nc == "r"  [ out = out + "13":  i = i + 3: skip: ]
                or   nc == "t"  [ out = out + "9":   i = i + 3: skip: ]
                or   nc == "\\" [ out = out + "92":  i = i + 4: skip: ]
                or   nc == "\"" [ out = out + "34":  i = i + 3: skip: ]
            ]
            out = out + "92": i = i + 2: skip:
        ]
        when c == "\"" [
            // bare double-quote: emit as byte 34 to avoid breaking NASM db syntax
            when in_q == 1 [ out = out + "\"": in_q = 0: ]
            when len(out) > 0 [ out = out + ",": ]
            out = out + "34": i = i + 1: skip:
        ]
        when in_q == 0 [
            when len(out) > 0 [ out = out + ",": ]
            out = out + "\"": in_q = 1:
        ]
        out = out + c: i = i + 1:
    ]
    when in_q == 1 [ out = out + "\"": ]
    when len(out) > 0 [ out = out + ",": ]
    give out + "0":
]

// ---- line store ----
fn load_lines(text src) -> int [
    let int i = 0: let int n = len(src): let int ls = 0:
    loop while i < n [
        when src{i} == "\n" [
            let text ln = sub(src, ls, i):
            when len(ln) > 0 and ln{len(ln) - 1} == "\r" [ ln = sub(ln, 0, len(ln) - 1): ]
            when len(ln) > 0 [ push(lines, ln): ]
            ls = i + 1:
        ]
        i = i + 1:
    ]
    when ls < n [
        let text ln = sub(src, ls, n):
        when len(ln) > 0 and ln{len(ln) - 1} == "\r" [ ln = sub(ln, 0, len(ln) - 1): ]
        when len(ln) > 0 [ push(lines, ln): ]
    ]
    give 0:
]

// ---- function table ----
fn fn_add(text name, text ret) -> int [
    push(fn_n, name): push(fn_r, fnret_tag(ret)): give 0:
]

fn fnret(text name) -> text [
    let int i = 1:
    loop while i < len(fn_n) [ when fn_n{i} == name [ give fn_r{i}: ] i = i + 1: ]
    give "i":
]

fn is_fn(text name) -> int [
    let int i = 1:
    loop while i < len(fn_n) [ when fn_n{i} == name [ give 1: ] i = i + 1: ]
    give 0:
]

// ---- global variable table ----
fn is_global(text name) -> int [
    let int i = 1:
    loop while i < len(gvar_n) [ when gvar_n{i} == name [ give 1: ] i = i + 1: ]
    give 0:
]

fn add_global(text name) -> int [
    when is_global(name) == 0 [ push(gvar_n, name): ] give 0:
]

fn settype_g(text name, text t) -> int [
    let int i = 1:
    loop while i < len(gtype_n) [
        when gtype_n{i} == name [ gtype_t{i} = t: give 0: ]
        i = i + 1:
    ]
    push(gtype_n, name): push(gtype_t, t): give 0:
]

fn gettype_g(text name) -> text [
    let int i = 1:
    loop while i < len(gtype_n) [ when gtype_n{i} == name [ give gtype_t{i}: ] i = i + 1: ]
    give "i":
]

// ---- per-function local slot table (cleared between functions) ----
fn reset_fn() -> int [
    loop while len(slot_n) > 1 [ pop(slot_n): ]
    nslots = 0: give 0:
]

fn alloc_slot(text name) -> int [
    let int i = 1:
    loop while i < len(slot_n) [ when slot_n{i} == name [ give 0: ] i = i + 1: ]
    push(slot_n, name): nslots = nslots + 1: give 0:
]

fn get_slot(text name) -> int [
    let int i = 1:
    loop while i < len(slot_n) [ when slot_n{i} == name [ give i: ] i = i + 1: ]
    give 0:
]

// ---- per-function type table ----
fn reset_vtypes() -> int [
    loop while len(vtype_n) > 1 [ pop(vtype_n): pop(vtype_t): ]
    give 0:
]

fn settype_v(text name, text t) -> int [
    let int i = 1:
    loop while i < len(vtype_n) [
        when vtype_n{i} == name [ vtype_t{i} = t: give 0: ]
        i = i + 1:
    ]
    push(vtype_n, name): push(vtype_t, t): give 0:
]

fn gettype_v(text name) -> text [
    let int i = 1:
    loop while i < len(vtype_n) [ when vtype_n{i} == name [ give vtype_t{i}: ] i = i + 1: ]
    give "~":  // not found sentinel
]

fn settype(text name, text t) -> int [
    when get_slot(name) != 0 [ give settype_v(name, t): ]
    give settype_g(name, t):
]

fn gettype(text name) -> text [
    let text t = gettype_v(name):
    when t != "~" [ give t: ]  // found locally
    give gettype_g(name):
]

fn addr(text name) -> text [
    let int s = get_slot(name):
    when s != 0 [ give "[rbp-" + totext(8 * s) + "]": ]
    give "[ig_g_" + name + "]":
]

// ---- type stack ----
fn tpush(text t) -> int [ push(ts, t): give 0: ]
fn tpop() -> text [ let text t = ts{len(ts) - 1}: pop(ts): give t: ]
fn tpeek() -> text [ give ts{len(ts) - 1}: ]
fn ts_del(int k) -> int [ loop while k > 0 [ pop(ts): k = k - 1: ] give 0: ]

// ---- internal label counter ----
fn newlab() -> text [ let text l = ".cg" + totext(cg_lab): cg_lab = cg_lab + 1: give l: ]

// ---- emit helpers ----
fn e(text s)  -> int [ iglog("    " + s): give 0: ]
fn el(text s) -> int [ iglog(s): give 0: ]

// ---- iterator tracking ----
fn reset_iter() -> int [
    loop while len(ik) > 1 [ pop(ik): pop(ie): ]
    cur_d = 0: give 0:
]

// Iterator frame slot byte offset: slots d=1-based depth, j=0/1/2
fn itoff(int d, int j) -> int [
    give 8 * (nslots + 3 * (d - 1) + j + 1):
]

// ---- global pre-scan: collect fn signatures + main-block globals ----
fn prescan() -> int [
    let int i = 1: let int in_fn = 0: let int in_main = 0:
    loop while i < len(lines) [
        let text line = lines{i}:
        when starts_with(line, "fn ") [
            fn_add(w1(line), w2(line)): in_fn = 1: in_main = 0:
        ]
        or line == "end" [ in_fn = 0: in_main = 0: ]
        or line == "main" [ in_main = 1: in_fn = 0: ]
        or in_fn == 0 and starts_with(line, "DECL ") [
            // top-level OR main-block declaration -> global
            let text dname = w2(line): let text dtype = w1(line):
            add_global(dname):
            when dtype == "text" or dtype == "s" [ settype_g(dname, "s"): ]
            // list type is deferred — actual "l" vs "ls" set during codegen DECL handler
        ]
        or in_fn == 0 and starts_with(line, "STORE ") [ add_global(w1(line)): ]
        or in_fn == 0 and starts_with(line, "FIX ")   [ add_global(w1(line)): ]
        or in_fn == 0 and starts_with(line, "REC ") [
            cur_rec = w1(line): push(rec_n, cur_rec):
        ]
        or in_fn == 0 and starts_with(line, "RFIELD ") [
            push(rfield_rn, cur_rec): push(rfield_ft, w1(line)): push(rfield_fn, w2(line)):
        ]
        or in_fn == 0 and starts_with(line, "ENUM ") [
            push(enum_n_cg, w1(line)):
        ]
        or in_fn == 0 and starts_with(line, "INEXT ") [
            let text v = w1(line):
            when v != "~" [ add_global(v): ]
        ]
        i = i + 1:
    ]
    give 0:
]

// ---- per-function pre-scan: allocate slots, find max iterator depth ----
fn prescan_fn(int lo, int hi) -> int [
    reset_fn():
    let int depth = 0: let int max_d = 0: let int i = lo + 1:
    loop while i < hi [
        let text line = lines{i}:
        when starts_with(line, "param ") [ alloc_slot(w2(line)): ]
        or starts_with(line, "DECL ")   [ alloc_slot(w2(line)): ]
        or starts_with(line, "FIX ")    [ alloc_slot(w1(line)): ]
        or starts_with(line, "INEXT ")  [
            let text v = w1(line):
            when v != "~" [ alloc_slot(v): ]
        ]
        or line == "RANGE" or line == "ITER" [
            depth = depth + 1: when depth > max_d [ max_d = depth: ]
        ]
        or line == "IPOP" [ depth = depth - 1: ]
        i = i + 1:
    ]
    give max_d:
]

// ---- generate NASM for one IR instruction ----
fn gen_ins(text line) -> int [
    let text op = w0(line):

    when op == "CONST" [
        let text v = w1(line):
        when v == "true"  [ e("mov rax, 1"): e("push rax"): tpush("i"): give 0: ]
        or   v == "false" [ e("xor eax, eax"): e("push rax"): tpush("i"): give 0: ]
        or   v == "none"  [ e("mov rax, 9223372036854775807"): e("push rax"): tpush("i"): give 0: ]
        e("mov rax, " + v): e("push rax"): tpush("i"): give 0:
    ]

    or op == "CONSTF" [
        let text dv = w1(line):
        e("mov rax, [" + dref(dv) + "]"): e("push rax"): tpush("f"): give 0:
    ]

    or op == "STR" [
        let text sv = rest(line):
        e("lea rax, [" + sref(sv) + "]"): e("push rax"): tpush("s"): give 0:
    ]

    or op == "LOAD" [
        let text nm = w1(line):
        e("mov rax, " + addr(nm)): e("push rax"): tpush(gettype(nm)): give 0:
    ]

    or op == "STORE" [
        let text nm = w1(line): let text t = tpop():
        settype(nm, t): e("pop rax"): e("mov " + addr(nm) + ", rax"): give 0:
    ]

    or op == "DECL" [
        let text nm = w2(line): let text t = tpop():
        settype(nm, t): e("pop rax"): e("mov " + addr(nm) + ", rax"): give 0:
    ]

    or op == "FIX" [
        let text nm = w1(line): let text t = tpop():
        settype(nm, t): e("pop rax"): e("mov " + addr(nm) + ", rax"): give 0:
    ]

    or op == "POP"  [ tpop(): e("add rsp, 8"): give 0: ]

    or op == "DUP"  [
        tpush(tpeek()): e("mov rax, [rsp]"): e("push rax"): give 0:
    ]

    or op == "NEG"  [
        when tpeek() == "f" [
            e("pop rax"): e("movq xmm0, rax"):
            e("pxor xmm1, xmm1"): e("subsd xmm1, xmm0"): e("movq rax, xmm1"):
            e("push rax"): give 0:
        ]
        e("pop rax"): e("neg rax"): e("push rax"): give 0:
    ]

    or op == "NOT"  [
        tpop(): tpush("i"):
        e("pop rax"): e("test rax, rax"): e("sete al"): e("movzx eax, al"): e("push rax"):
        give 0:
    ]

    or op == "BOOL" [
        tpop(): tpush("i"):
        e("pop rax"): e("test rax, rax"): e("setne al"): e("movzx eax, al"): e("push rax"):
        give 0:
    ]

    or op == "BIN" [
        let text oper = w1(line):
        let text rt = tpop(): let text lt = tpop():
        // string concatenation
        when oper == "+" and (is_text_t(lt) == 1 or is_text_t(rt) == 1) [
            when is_text_t(lt) == 1 and is_text_t(rt) == 1 [
                e("pop rdx"): e("pop rcx"): e("call ig_concat"):
            ]
            or is_text_t(lt) == 1 [
                e("pop rcx"):
                when is_float_t(rt) == 1 [ e("movq xmm0, rcx"): e("call ig_dbl_to_str"): ]
                else [ e("call ig_int_to_str"): ]
                e("mov rdx, rax"): e("pop rcx"): e("call ig_concat"):
            ]
            else [
                e("pop rbx"): e("pop rcx"):
                when is_float_t(lt) == 1 [ e("movq xmm0, rcx"): e("call ig_dbl_to_str"): ]
                else [ e("call ig_int_to_str"): ]
                e("mov rcx, rax"): e("mov rdx, rbx"): e("call ig_concat"):
            ]
            e("push rax"): tpush("s"): give 0:
        ]
        // string equality
        when (oper == "==" or oper == "!=") and is_text_t(lt) == 1 and is_text_t(rt) == 1 [
            e("pop rdx"): e("pop rcx"): e("call ig_streq"):
            when oper == "!=" [ e("xor rax, 1"): ]
            e("push rax"): tpush("i"): give 0:
        ]
        // float arithmetic / compare
        when is_float_t(lt) == 1 or is_float_t(rt) == 1 [
            e("pop rbx"): e("pop rax"):
            when is_float_t(lt) == 1 [ e("movq xmm0, rax"): ] else [ e("cvtsi2sd xmm0, rax"): ]
            when is_float_t(rt) == 1 [ e("movq xmm1, rbx"): ] else [ e("cvtsi2sd xmm1, rbx"): ]
            when oper == "+" [ e("addsd xmm0, xmm1"): e("movq rax, xmm0"): e("push rax"): tpush("f"): ]
            or oper == "-" [ e("subsd xmm0, xmm1"): e("movq rax, xmm0"): e("push rax"): tpush("f"): ]
            or oper == "*" [ e("mulsd xmm0, xmm1"): e("movq rax, xmm0"): e("push rax"): tpush("f"): ]
            or oper == "/" [ e("divsd xmm0, xmm1"): e("movq rax, xmm0"): e("push rax"): tpush("f"): ]
            or oper == "%" [
                e("movsd xmm2, xmm0"): e("divsd xmm0, xmm1"): e("cvttsd2si rax, xmm0"):
                e("cvtsi2sd xmm0, rax"): e("mulsd xmm0, xmm1"): e("movsd xmm1, xmm0"):
                e("movsd xmm0, xmm2"): e("subsd xmm0, xmm1"): e("movq rax, xmm0"):
                e("push rax"): tpush("f"):
            ]
            else [
                let text cc2 = "e":
                when oper == "!=" [ cc2 = "ne": ]
                or oper == "<"  [ cc2 = "b": ]
                or oper == ">"  [ cc2 = "a": ]
                or oper == "<=" [ cc2 = "be": ]
                or oper == ">=" [ cc2 = "ae": ]
                e("comisd xmm0, xmm1"): e("set" + cc2 + " al"): e("movzx eax, al"):
                e("push rax"): tpush("i"):
            ]
            give 0:
        ]
        // integer arithmetic / compare
        tpush("i"): e("pop rbx"): e("pop rax"):
        when oper == "+"  [ e("add rax, rbx"): ]
        or   oper == "-"  [ e("sub rax, rbx"): ]
        or   oper == "*"  [ e("imul rax, rbx"): ]
        or   oper == "/" or oper == "%" [
            e("test rbx, rbx"): e("jz ig_div0"):
            e("cqo"): e("idiv rbx"):
            when oper == "%" [ e("mov rax, rdx"): ]
        ]
        else [
            let text cc = "e":
            when oper == "!=" [ cc = "ne": ]
            or   oper == "<"  [ cc = "l": ]
            or   oper == ">"  [ cc = "g": ]
            or   oper == "<=" [ cc = "le": ]
            or   oper == ">=" [ cc = "ge": ]
            e("cmp rax, rbx"): e("set" + cc + " al"): e("movzx eax, al"):
        ]
        e("push rax"): give 0:
    ]

    or op == "INDEX" [
        let text it = tpop(): let text ot = tpop():
        when is_text_t(ot) == 1 [
            e("pop rdx"): e("pop rcx"): e("call ig_text_index"):
            e("push rax"): tpush("s"): give 0:
        ]
        e("pop rdx"): e("pop rcx"): e("call ig_list_get"):
        e("push rax"): tpush(elem_t(ot)): give 0:
    ]

    or op == "SETIDX" [
        tpop(): tpop(): tpop():
        e("pop r8"): e("pop rdx"): e("pop rcx"): e("call ig_list_set"): give 0:
    ]

    or op == "LIST" [
        let int kk = toint(w1(line)):
        // peek at element type before popping
        let text et = "i":
        when kk > 0 [ et = ts{len(ts) - kk}: ]
        ts_del(kk):
        let int lcap = 4: when kk > 4 [ lcap = kk: ]
        e("mov ecx, " + totext(lcap)): e("call ig_list_new"):
        e("mov r10, [rax+16]"):
        let int jj = kk - 1:
        loop while jj >= 0 [
            e("pop rcx"): e("mov [r10+" + totext(8 * jj) + "], rcx"):
            jj = jj - 1:
        ]
        e("mov qword [rax], " + totext(kk)): e("push rax"):
        when et == "s" [ tpush("ls"): ] else [ tpush("l"): ]
        give 0:
    ]

    or op == "MAP" [
        let int kk = toint(w1(line)):
        ts_del(2 * kk):
        e("mov ecx, 8"): e("call ig_map_new"): e("mov rbx, rax"):
        let int jj = 0:
        loop while jj < kk [
            e("pop r8"): e("pop rdx"): e("mov rcx, rbx"): e("call ig_map_set"):
            jj = jj + 1:
        ]
        e("push rbx"): tpush("map"):
        give 0:
    ]

    or op == "JMP" [ e("jmp " + lname(w1(line))): give 0: ]

    or op == "JF" [
        tpop(): e("pop rax"): e("test rax, rax"): e("jz " + lname(w1(line))): give 0:
    ]

    or op == "JT" [
        tpop(): e("pop rax"): e("test rax, rax"): e("jnz " + lname(w1(line))): give 0:
    ]

    or op == "RANGE" [
        tpop(): tpop(): tpop():
        cur_d = cur_d + 1: push(ik, "range"): push(ie, "i"):
        let text Ldir = newlab():
        e("pop rcx"): e("pop rbx"): e("pop rax"):
        e("mov r10, 9223372036854775807"):
        e("cmp rcx, r10"): e("jne " + Ldir):
        e("mov rcx, 1"): e("cmp rax, rbx"): e("jle " + Ldir):
        e("mov rcx, -1"):
        el(Ldir + ":"):
        e("mov [rbp-" + totext(itoff(cur_d, 0)) + "], rax"):
        e("mov [rbp-" + totext(itoff(cur_d, 1)) + "], rbx"):
        e("mov [rbp-" + totext(itoff(cur_d, 2)) + "], rcx"):
        give 0:
    ]

    or op == "ITER" [
        let text lt = tpop():
        cur_d = cur_d + 1: push(ik, "seq"): push(ie, elem_t(lt)):
        e("pop rax"):
        e("mov r10, [rax]"): e("mov r11, [rax+16]"):
        e("mov qword [rbp-" + totext(itoff(cur_d, 0)) + "], 0"):
        e("mov [rbp-" + totext(itoff(cur_d, 1)) + "], r10"):
        e("mov [rbp-" + totext(itoff(cur_d, 2)) + "], r11"):
        give 0:
    ]

    or op == "INEXT" [
        let text ivar = w1(line): let text itgt = w2(line):
        let text kind = ik{len(ik) - 1}:
        when kind == "range" [
            let text Ldn = newlab(): let text Lbd = newlab():
            e("mov rax, [rbp-" + totext(itoff(cur_d, 0)) + "]"):
            e("mov rbx, [rbp-" + totext(itoff(cur_d, 1)) + "]"):
            e("mov rcx, [rbp-" + totext(itoff(cur_d, 2)) + "]"):
            e("test rcx, rcx"): e("js " + Ldn):
            e("cmp rax, rbx"): e("jg " + lname(itgt)): e("jmp " + Lbd):
            el(Ldn + ":"): e("cmp rax, rbx"): e("jl " + lname(itgt)):
            el(Lbd + ":"):
            when ivar != "~" [ settype(ivar, "i"): e("mov " + addr(ivar) + ", rax"): ]
            e("add rax, rcx"):
            e("mov [rbp-" + totext(itoff(cur_d, 0)) + "], rax"):
        ]
        else [
            e("mov rax, [rbp-" + totext(itoff(cur_d, 0)) + "]"):
            e("cmp rax, [rbp-" + totext(itoff(cur_d, 1)) + "]"):
            e("jae " + lname(itgt)):
            e("mov r10, [rbp-" + totext(itoff(cur_d, 2)) + "]"):
            e("mov rcx, [r10+rax*8]"): e("inc rax"):
            e("mov [rbp-" + totext(itoff(cur_d, 0)) + "], rax"):
            when ivar != "~" [
                settype(ivar, ie{len(ie) - 1}): e("mov " + addr(ivar) + ", rcx"):
            ]
        ]
        give 0:
    ]

    or op == "IPOP" [ cur_d = cur_d - 1: pop(ik): pop(ie): give 0: ]

    or op == "TRYPUSH" [
        e("lea rcx, [" + lname(w1(line)) + "]"): e("call ig_exc_push"): give 0:
    ]
    or op == "TRYPOP" [ e("call ig_exc_pop"): give 0: ]

    or op == "REC"      [ give 0: ]
    or op == "RFIELD"   [ give 0: ]
    or op == "ENUM"     [ give 0: ]
    or op == "EVARIANT" [ give 0: ]
    or op == "TOSTR" [
        when tpeek() == "s" [ give 0: ]
        when tpeek() == "f" [
            tpop(): e("pop rax"): e("movq xmm0, rax"): e("call ig_dbl_to_str"): e("push rax"): tpush("s"):
            give 0:
        ]
        tpop(): e("pop rcx"): e("call ig_int_to_str"): e("push rax"): tpush("s"):
        give 0:
    ]

    or op == "NEW" [
        let text rname = w1(line):
        let int sz = rec_size(rname): let int fc = sz / 8:
        e("mov ecx, " + totext(sz)): e("call ig_alloc"):
        let int fi = fc - 1:
        loop while fi >= 0 [
            e("pop r10"): e("mov [rax+" + totext(fi * 8) + "], r10"):
            fi = fi - 1:
        ]
        e("push rax"): ts_del(fc): tpush(rname): give 0:
    ]

    or op == "FGET" [
        let text rname = w1(line): let text fname = w2(line):
        let int off = field_offset(rname, fname):
        tpop(): e("pop rcx"):
        e("mov rax, [rcx+" + totext(off) + "]"): e("push rax"):
        tpush(ir_to_tag(rfield_ft_get(rname, fname))): give 0:
    ]

    or op == "FSET" [
        let text rname = w1(line): let text fname = w2(line):
        let int off = field_offset(rname, fname):
        tpop(): tpop():
        e("pop r10"): e("pop rcx"):
        e("mov [rcx+" + totext(off) + "], r10"): give 0:
    ]

    or op == "LOG" [
        let text level = w1(line): let int kk = toint(w2(line)):
        // Save arg types before popping
        let list at = {"~"}:
        let int tai = len(ts) - kk: let int taj = 0:
        loop while taj < kk [ push(at, ts{tai + taj}): taj = taj + 1: ]
        ts_del(kk):
        let int is_err = 0:
        when level == "err" or level == "warn" [ is_err = 1: ]
        let text pfn = "ig_print_str":
        when is_err == 1 [ pfn = "ig_print_err": ]
        when is_err == 1 [
            e("lea rcx, [" + sref("[" + level + "] ") + "]"): e("call " + pfn):
        ]
        let int jj = 0:
        loop while jj < kk [
            when jj > 0 [ e("lea rcx, [" + sref(" ") + "]"): e("call " + pfn): ]
            e("mov rcx, [rsp+" + totext(8 * (kk - 1 - jj)) + "]"):
            let text at_j = at{jj + 1}:
            when at_j == "s" [ e("call " + pfn): ]
            or is_list_t(at_j) == 1 [
                let text lfn = "ig_print_list":
                when is_err == 1 [ lfn = "ig_print_list_err": ]
                when elem_t(at_j) == "s" [ e("mov edx, 1"): ] else [ e("xor edx, edx"): ]
                e("call " + lfn):
            ]
            or at_j == "f" [
                e("movq xmm0, rcx"): e("call ig_dbl_to_str"): e("mov rcx, rax"): e("call " + pfn):
            ]
            else [
                let text ifn = "ig_print_int":
                when is_err == 1 [ ifn = "ig_print_int_err": ]
                e("call " + ifn):
            ]
            jj = jj + 1:
        ]
        e("lea rcx, [str_nl]"): e("call " + pfn):
        when kk > 0 [ e("add rsp, " + totext(8 * kk)): ]
        give 0:
    ]

    or op == "CALL" [
        let text nm = w1(line): let int argc = toint(w2(line)):
        // Save top argc types before popping
        let list at = {"~"}:
        let int tai = len(ts) - argc: let int taj = 0:
        loop while taj < argc [ push(at, ts{tai + taj}): taj = taj + 1: ]
        ts_del(argc):
        // User-defined function
        when is_fn(nm) == 1 [
            e("call ig_fn_" + nm):
            when argc > 0 [ e("add rsp, " + totext(8 * argc)): ]
            e("push rax"): tpush(fnret(nm)): give 0:
        ]
        // Builtins
        when nm == "len" [
            let text t0 = at{1}:
            e("pop rcx"):
            when is_list_t(t0) == 1 or t0 == "map" [ e("mov rax, [rcx]"): ]
            else [ e("call ig_strlen"): ]
            e("push rax"): tpush("i"): give 0:
        ]
        when nm == "push" [
            let text vt = at{2}:
            e("pop rdx"): e("pop rcx"): e("call ig_list_push"):
            e("push rax"):
            when vt == "s" [ tpush("ls"): ] else [ tpush("l"): ]
            give 0:
        ]
        when nm == "pop" [
            let text lt = at{1}:
            e("pop rcx"): e("call ig_list_pop"):
            e("push rax"): tpush(elem_t(lt)): give 0:
        ]
        when nm == "totext"   [
            let text t0 = at{1}:
            when t0 == "f" [
                e("pop rax"): e("movq xmm0, rax"): e("call ig_dbl_to_str"): e("push rax"): tpush("s"): give 0:
            ]
            e("pop rcx"): e("call ig_int_to_str"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "toint"    [ e("pop rcx"): e("call ig_str_to_int"): e("push rax"): tpush("i"): give 0: ]
        when nm == "tofloat"  [ e("pop rcx"): e("call ig_str_to_float"): e("push rax"): tpush("f"): give 0: ]
        when nm == "int_to_float" [
            e("pop rax"): e("cvtsi2sd xmm0, rax"): e("movq rax, xmm0"): e("push rax"): tpush("f"): give 0:
        ]
        when nm == "float_to_int" [
            e("pop rax"): e("movq xmm0, rax"): e("cvttsd2si rax, xmm0"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "ask"      [ e("pop rcx"): e("call ig_print_str"): e("call ig_readline"): e("push rax"): tpush("s"): give 0: ]
        when nm == "sub"      [ e("pop r8"): e("pop rdx"): e("pop rcx"): e("call ig_substr"): e("push rax"): tpush("s"): give 0: ]
        when nm == "readfile" [ e("pop rcx"): e("call ig_readfile"): e("push rax"): tpush("s"): give 0: ]
        when nm == "writefile"[ e("pop rdx"): e("pop rcx"): e("call ig_writefile"): e("push rax"): tpush("i"): give 0: ]
        when nm == "file_open" [ e("pop rcx"): e("call ig_file_open"): e("push rax"): tpush("i"): give 0: ]
        when nm == "file_read_chunk" [
            e("pop rdx"): e("pop rcx"): e("call ig_file_read_chunk"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "file_eof" [ e("pop rcx"): e("call ig_file_eof"): e("push rax"): tpush("i"): give 0: ]
        when nm == "file_close" [ e("pop rcx"): e("call ig_file_close"): e("push rax"): tpush("i"): give 0: ]
        when nm == "quit" [
            e("pop rcx"): e("and rsp, -16"): e("sub rsp, 32"):
            e("call ExitProcess"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "abs" [
            let text t0 = at{1}:
            when t0 == "f" [
                e("pop rax"): e("btr rax, 63"): e("push rax"): tpush("f"): give 0:
            ]
            let text La = newlab():
            e("pop rax"): e("test rax, rax"): e("jns " + La): e("neg rax"):
            el(La + ":"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "min" [
            let text t0 = at{1}: let text t1 = at{2}:
            when t0 == "f" or t1 == "f" [
                e("pop rbx"): e("pop rax"):
                when t0 == "f" [ e("movq xmm0, rax"): ] else [ e("cvtsi2sd xmm0, rax"): ]
                when t1 == "f" [ e("movq xmm1, rbx"): ] else [ e("cvtsi2sd xmm1, rbx"): ]
                e("comisd xmm0, xmm1"): e("movq rax, xmm0"): e("movq rbx, xmm1"): e("cmova rax, rbx"):
                e("push rax"): tpush("f"): give 0:
            ]
            e("pop rbx"): e("pop rax"): e("cmp rax, rbx"): e("cmovg rax, rbx"):
            e("push rax"): tpush("i"): give 0:
        ]
        when nm == "max" [
            let text t0 = at{1}: let text t1 = at{2}:
            when t0 == "f" or t1 == "f" [
                e("pop rbx"): e("pop rax"):
                when t0 == "f" [ e("movq xmm0, rax"): ] else [ e("cvtsi2sd xmm0, rax"): ]
                when t1 == "f" [ e("movq xmm1, rbx"): ] else [ e("cvtsi2sd xmm1, rbx"): ]
                e("comisd xmm0, xmm1"): e("movq rax, xmm0"): e("movq rbx, xmm1"): e("cmovb rax, rbx"):
                e("push rax"): tpush("f"): give 0:
            ]
            e("pop rbx"): e("pop rax"): e("cmp rax, rbx"): e("cmovl rax, rbx"):
            e("push rax"): tpush("i"): give 0:
        ]
        when nm == "ord" [
            e("pop rcx"): e("movzx rax, byte [rcx]"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "chr" [
            e("pop rcx"): e("call ig_chr"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "clock" [
            e("call ig_clock"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "argc" [
            e("mov rcx, [g_argv]"): e("mov rax, [rcx]"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "argv" [
            e("pop rdx"): e("mov rcx, [g_argv]"): e("call ig_list_get"):
            e("push rax"): tpush("s"): give 0:
        ]
        when nm == "lasterror" [
            e("mov rax, [g_last_error]"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "getenv" [
            e("pop rcx"): e("call ig_getenv"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "exedir" [
            e("call ig_exedir"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "sock_listen" [
            e("pop rcx"): e("call ig_sock_listen"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "sock_accept" [
            e("pop rcx"): e("call ig_sock_accept"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "sock_recv" [
            e("pop rcx"): e("call ig_sock_recv"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "sock_send" [
            e("pop rdx"): e("pop rcx"): e("call ig_sock_send"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "sock_close" [
            e("pop rcx"): e("call ig_sock_close"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "map_new" [
            e("mov ecx, 8"): e("call ig_map_new"): e("push rax"): tpush("map"): give 0:
        ]
        when nm == "map_set" [
            e("pop r8"): e("pop rdx"): e("pop rcx"): e("call ig_map_set"):
            e("push rax"): tpush("map"): give 0:
        ]
        when nm == "map_get_text" [
            e("pop rdx"): e("pop rcx"): e("call ig_map_get"): e("push rax"): tpush("s"): give 0:
        ]
        when nm == "map_get_int" [
            e("pop rdx"): e("pop rcx"): e("call ig_map_get"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "map_get_float" [
            e("pop rdx"): e("pop rcx"): e("call ig_map_get"): e("push rax"): tpush("f"): give 0:
        ]
        when nm == "map_has" [
            e("pop rdx"): e("pop rcx"): e("call ig_map_has"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "map_keys" [
            e("pop rcx"): e("call ig_map_keys"): e("push rax"): tpush("ls"): give 0:
        ]
        when nm == "system" [
            e("pop rcx"): e("call ig_system"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "print" [
            e("pop rcx"): e("call ig_print_str"): e("xor eax, eax"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "println" [
            e("pop rcx"): e("call ig_print_str"):
            e("lea rcx, [str_nl]"): e("call ig_print_str"):
            e("xor eax, eax"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "printout" [
            // like iglog(...): multi-arg, space-separated, auto-stringified —
            // but no trailing newline and no "[level]" prefix.
            let int jj = 0:
            loop while jj < argc [
                when jj > 0 [ e("lea rcx, [" + sref(" ") + "]"): e("call ig_print_str"): ]
                e("mov rcx, [rsp+" + totext(8 * (argc - 1 - jj)) + "]"):
                let text at_j = at{jj + 1}:
                when at_j == "s" [ e("call ig_print_str"): ]
                or is_list_t(at_j) == 1 [
                    when elem_t(at_j) == "s" [ e("mov edx, 1"): ] else [ e("xor edx, edx"): ]
                    e("call ig_print_list"):
                ]
                or at_j == "f" [
                    e("movq xmm0, rcx"): e("call ig_dbl_to_str"): e("mov rcx, rax"): e("call ig_print_str"):
                ]
                else [ e("call ig_print_int"): ]
                jj = jj + 1:
            ]
            when argc > 0 [ e("add rsp, " + totext(8 * argc)): ]
            e("xor eax, eax"): e("push rax"): tpush("i"): give 0:
        ]
        when nm == "run_coroutines" [
            e("call ig_run_coroutines"): e("xor eax, eax"): e("push rax"): tpush("i"): give 0:
        ]
        // Unknown — fall through as user fn
        e("call ig_fn_" + nm):
        when argc > 0 [ e("add rsp, " + totext(8 * argc)): ]
        e("push rax"): tpush("i"): give 0:
    ]

    or op == "RET"  [
        tpop(): e("pop rax"):
        when cur_fn_is_coro == 1 [ e("call ig_coro_finish"): give 0: ]
        e("mov rsp, rbp"): e("pop rbp"): e("ret"): give 0:
    ]
    or op == "RETN" or op == "HALT" [
        when op == "RETN" and cur_fn_is_coro == 1 [ e("call ig_coro_finish"): give 0: ]
        e("xor eax, eax"): e("mov rsp, rbp"): e("pop rbp"): e("ret"): give 0:
    ]
    or op == "SPAWN" [
        e("lea rcx, [ig_fn_" + w1(line) + "]"): e("call ig_coro_spawn"): give 0:
    ]
    or op == "YIELD" [ e("call ig_coro_yield"): give 0: ]
    or starts_with(line, ".L") [ el(lname(line) + ":"): give 0: ]

    give 0:  // structural lines handled by caller
]

// ---- generate one function (fn_lo points to "fn name ret" line) ----
fn gen_fn(int lo, int hi) -> int [
    let text fname = w1(lines{lo}):
    let int max_d = prescan_fn(lo, hi):
    reset_vtypes(): reset_iter():
    loop while len(ts) > 1 [ pop(ts): ]

    // a function that uses `yield` anywhere is a coroutine body — its RET/RETN
    // exits go through ig_coro_finish instead of a normal `ret` (see the RET/
    // RETN opcode handlers). Inferred automatically, no separate declaration.
    cur_fn_is_coro = 0:
    let int cfi = lo + 1:
    loop while cfi < hi [
        when lines{cfi} == "YIELD" [ cur_fn_is_coro = 1: ]
        cfi = cfi + 1:
    ]

    let int frame = 8 * (nslots + 3 * max_d):

    // collect param lines
    let list plines = {"~"}:
    let int pi = lo + 1:
    loop while pi < hi and starts_with(lines{pi}, "param ") [
        push(plines, lines{pi}): pi = pi + 1:
    ]
    let int nparams = len(plines) - 1:

    el("ig_fn_" + fname + ":"):
    e("push rbp"): e("mov rbp, rsp"):
    when frame > 0 [ e("sub rsp, " + totext(frame)): ]

    // copy params from caller stack to local slots
    let int pj = 0:
    loop while pj < nparams [
        let text pln = plines{pj + 1}:
        let text pname = w2(pln): let text ptype = w1(pln):
        e("mov rax, [rbp+" + totext(16 + 8 * (nparams - 1 - pj)) + "]"):
        e("mov [rbp-" + totext(8 * get_slot(pname)) + "], rax"):
        when ptype == "text" or ptype == "s" [ settype_v(pname, "s"): ]
        or ptype == "list" or ptype == "l"   [ settype_v(pname, "ls"): ]
        or ptype == "int" or ptype == "bool" [ settype_v(pname, "i"): ]
        else [ settype_v(pname, ptype): ]
        pj = pj + 1:
    ]

    // emit instructions
    let int i = pi:
    loop while i < hi [
        let text line = lines{i}:
        when starts_with(line, "param ") or line == "end" or starts_with(line, "fn ") [
            i = i + 1: skip:
        ]
        gen_ins(line): i = i + 1:
    ]
    give 0:
]

// ---- generate main block (lo points to "main" line) ----
// gen_main: pre_lo..pre_hi = top-level init code, main_lo..main_hi = main block
// Pass pre_lo=pre_hi=0 if no top-level code; main_lo=main_hi=0 if no main block.
fn gen_main(int pre_lo, int pre_hi, int main_lo, int main_hi) -> int [
    reset_fn(): reset_vtypes(): reset_iter():
    loop while len(ts) > 1 [ pop(ts): ]
    // scan both sections for max iterator depth (skip fn blocks in pre range)
    let int depth = 0: let int max_d = 0: let int in_fn = 0:
    let int si = pre_lo:
    loop while si < pre_hi [
        let text ln = lines{si}:
        when starts_with(ln, "fn ") [ in_fn = 1: ]
        or ln == "end" and in_fn == 1 [ in_fn = 0: ]
        or in_fn == 0 [
            when ln == "RANGE" or ln == "ITER" [
                depth = depth + 1: when depth > max_d [ max_d = depth: ]
            ]
            or ln == "IPOP" [ depth = depth - 1: ]
        ]
        si = si + 1:
    ]
    when main_lo > 0 [
        let int mi = main_lo + 1:
        loop while mi < main_hi [
            let text ln = lines{mi}:
            when ln == "RANGE" or ln == "ITER" [
                depth = depth + 1: when depth > max_d [ max_d = depth: ]
            ]
            or ln == "IPOP" [ depth = depth - 1: ]
            mi = mi + 1:
        ]
    ]
    let int frame = 8 * (3 * max_d):
    el("ig_user_main:"):
    e("push rbp"): e("mov rbp, rsp"):
    when frame > 0 [ e("sub rsp, " + totext(frame)): ]
    // emit top-level init code (skip fn blocks — globals may appear between functions)
    let int in_fn2 = 0: let int pi = pre_lo:
    loop while pi < pre_hi [
        let text pln = lines{pi}:
        when starts_with(pln, "fn ") [ in_fn2 = 1: ]
        or pln == "end" and in_fn2 == 1 [ in_fn2 = 0: ]
        or in_fn2 == 0 [ gen_ins(pln): ]
        pi = pi + 1:
    ]
    // emit main block body
    when main_lo > 0 [
        let int j = main_lo + 1:
        loop while j < main_hi [
            let text line = lines{j}:
            when line != "end" [ gen_ins(line): ]
            j = j + 1:
        ]
    ]
    give 0:
]

// ---- emit runtime library ----
fn gen_runtime() -> int [
    el("ig_alloc:"):
    e("add rcx, 15"): e("and rcx, -16"): e("mov rax, [heap_cur]"):
    e("lea r10, [rax+rcx]"): e("cmp r10, [heap_end]"): e("ja ig_oom"):
    e("mov [heap_cur], r10"): e("ret"):

    el("ig_strlen:"):
    e("xor eax, eax"):
    el(".lsl: cmp byte [rcx+rax], 0"): e("je .dsl"):
    e("inc rax"): e("jmp .lsl"):
    el(".dsl: ret"):

    el("ig_concat:"):
    e("push rsi"): e("push rdi"): e("push rbx"): e("push r12"):
    e("mov rsi, rcx"): e("mov rdi, rdx"):
    e("call ig_strlen"): e("mov rbx, rax"):
    e("mov rcx, rdi"): e("call ig_strlen"): e("mov r12, rax"):
    e("lea rcx, [rbx+r12+1]"): e("call ig_alloc"):
    e("xor r9d, r9d"):
    el(".ca: cmp r9, rbx"): e("je .cb0"):
    e("mov r8b, [rsi+r9]"): e("mov [rax+r9], r8b"): e("inc r9"): e("jmp .ca"):
    el(".cb0: lea r10, [rax+rbx]"): e("xor r9d, r9d"):
    el(".cb: cmp r9, r12"): e("je .cfin"):
    e("mov r8b, [rdi+r9]"): e("mov [r10+r9], r8b"): e("inc r9"): e("jmp .cb"):
    el(".cfin: mov byte [r10+r12], 0"):
    e("pop r12"): e("pop rbx"): e("pop rdi"): e("pop rsi"): e("ret"):

    el("ig_streq:"):
    e("xor r9d, r9d"):
    el(".lseq: mov al, [rcx+r9]"): e("mov r8b, [rdx+r9]"):
    e("cmp al, r8b"): e("jne .nseq"):
    e("test al, al"): e("je .eseq"): e("inc r9"): e("jmp .lseq"):
    el(".eseq: mov eax, 1"): e("ret"):
    el(".nseq: xor eax, eax"): e("ret"):

    el("ig_int_to_str:"):
    e("push rbx"): e("push rsi"): e("mov rax, rcx"):
    e("lea rsi, [numbuf+30]"): e("mov byte [rsi], 0"): e("xor r11d, r11d"):
    e("test rax, rax"): e("jns .ci2s"): e("neg rax"): e("mov r11d, 1"):
    el(".ci2s: mov rbx, 10"):
    el(".di2s: xor edx, edx"): e("div rbx"):
    e("add dl, '0'"): e("dec rsi"): e("mov [rsi], dl"):
    e("test rax, rax"): e("jnz .di2s"):
    e("test r11d, r11d"): e("jz .cpi2s"):
    e("dec rsi"): e("mov byte [rsi], '-'"):
    el(".cpi2s: mov rcx, rsi"): e("call ig_strlen"): e("mov rbx, rax"):
    e("lea rcx, [rax+1]"): e("call ig_alloc"):
    e("xor r9d, r9d"):
    el(".ki2s: cmp r9, rbx"): e("je .zi2s"):
    e("mov r8b, [rsi+r9]"): e("mov [rax+r9], r8b"): e("inc r9"): e("jmp .ki2s"):
    el(".zi2s: mov byte [rax+rbx], 0"):
    e("pop rsi"): e("pop rbx"): e("ret"):

    // ===== float <-> text =====

    // ig_frac6_to_str(rcx=frac 0..999999) -> rax = exactly 6-char zero-padded digit string
    el("ig_frac6_to_str:"):
    e("push rbx"): e("push rsi"):
    e("mov rbx, rcx"):
    e("mov ecx, 7"): e("call ig_alloc"): e("mov rsi, rax"):
    e("mov byte [rsi+6], 0"):
    e("mov rax, rbx"): e("mov r9, 5"):
    el(".f6_loop: xor edx, edx"): e("mov rcx, 10"): e("div rcx"):
    e("add dl, '0'"): e("mov [rsi + r9], dl"):
    e("dec r9"): e("cmp r9, 0"): e("jge .f6_loop"):
    e("mov rax, rsi"):
    e("pop rsi"): e("pop rbx"): e("ret"):

    // ig_rtrim_zeros(rcx=text) -> rax = text with trailing '0' chars stripped (may be "")
    el("ig_rtrim_zeros:"):
    e("push rsi"):
    e("mov rsi, rcx"): e("mov rcx, rsi"): e("call ig_strlen"): e("mov r8, rax"):
    el(".rz_loop: cmp r8, 0"): e("je .rz_done"):
    e("cmp byte [rsi + r8 - 1], '0'"): e("jne .rz_done"):
    e("dec r8"): e("jmp .rz_loop"):
    el(".rz_done: mov rcx, rsi"): e("xor edx, edx"): e("call ig_substr"):
    e("pop rsi"): e("ret"):

    // ig_dbl_to_str(xmm0=value) -> rax = text, 6-decimal precision, trailing zeros trimmed
    el("ig_dbl_to_str:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("push rbx"): e("push rsi"): e("push rdi"): e("push r12"): e("push r13"):
    e("xor r13d, r13d"):
    e("pxor xmm1, xmm1"): e("comisd xmm0, xmm1"): e("jae .dts_pos"):
    e("mov r13d, 1"): e("pxor xmm1, xmm1"): e("subsd xmm1, xmm0"): e("movsd xmm0, xmm1"):
    el(".dts_pos: movsd xmm1, [dbl_scale]"): e("mulsd xmm0, xmm1"): e("cvtsd2si rax, xmm0"):
    e("mov rbx, 1000000"): e("cqo"): e("idiv rbx"):
    e("mov rsi, rax"): e("mov rdi, rdx"):
    e("mov rcx, rsi"): e("call ig_int_to_str"): e("mov r12, rax"):
    e("mov rcx, rdi"): e("call ig_frac6_to_str"):
    e("mov rcx, rax"): e("call ig_rtrim_zeros"): e("mov rbx, rax"):
    e("mov rcx, rbx"): e("call ig_strlen"): e("test rax, rax"): e("jz .dts_nofrac"):
    e("lea rcx, [str_dot]"): e("mov rdx, rbx"): e("call ig_concat"):
    e("mov rcx, r12"): e("mov rdx, rax"): e("call ig_concat"): e("mov r12, rax"):
    el(".dts_nofrac: test r13d, r13d"): e("jz .dts_done"):
    e("lea rcx, [str_minus]"): e("mov rdx, r12"): e("call ig_concat"): e("mov r12, rax"):
    el(".dts_done: mov rax, r12"):
    e("pop r13"): e("pop r12"): e("pop rdi"): e("pop rsi"): e("pop rbx"):
    e("pop rbp"): e("ret"):

    // ig_str_to_float(rcx=text) -> rax = double bits (parses "-?digits(.digits)?")
    el("ig_str_to_float:"):
    e("push rbx"): e("push rsi"):
    e("mov rsi, rcx"):
    e("xor r8d, r8d"): e("xor r9d, r9d"): e("xor r10d, r10d"):
    e("cmp byte [rsi], '-'"): e("jne .sf_nosign"): e("mov r8d, 1"): e("inc rsi"):
    el(".sf_nosign: xor rax, rax"):
    el(".sf_loop: movzx ecx, byte [rsi]"): e("test cl, cl"): e("jz .sf_done"):
    e("cmp cl, '.'"): e("je .sf_isdot"):
    e("cmp cl, '0'"): e("jb ig_badnum"): e("cmp cl, '9'"): e("ja ig_badnum"):
    e("imul rax, rax, 10"): e("sub cl, '0'"): e("movzx ecx, cl"): e("add rax, rcx"):
    e("test r10d, r10d"): e("jz .sf_noinc"): e("inc r9"):
    el(".sf_noinc: inc rsi"): e("jmp .sf_loop"):
    el(".sf_isdot: mov r10d, 1"): e("inc rsi"): e("jmp .sf_loop"):
    el(".sf_done: cvtsi2sd xmm0, rax"):
    e("test r9, r9"): e("jz .sf_nodiv"): e("movsd xmm1, [dbl_ten]"):
    el(".sf_divloop: divsd xmm0, xmm1"): e("dec r9"): e("jnz .sf_divloop"):
    el(".sf_nodiv: test r8d, r8d"): e("jz .sf_possign"):
    e("pxor xmm1, xmm1"): e("subsd xmm1, xmm0"): e("movsd xmm0, xmm1"):
    el(".sf_possign: movq rax, xmm0"):
    e("pop rsi"): e("pop rbx"): e("ret"):

    el("ig_readline:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"):
    e("mov ecx, 256"): e("call ig_alloc"): e("mov rsi, rax"):
    e("and rsp, -16"): e("sub rsp, 48"):
    e("mov rcx, [stdin_h]"): e("mov rdx, rsi"): e("mov r8d, 255"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call ReadFile"):
    e("mov rax, [written]"):
    el(".srln: test rax, rax"): e("jz .drl"):
    e("mov r8b, [rsi+rax-1]"): e("cmp r8b, 13"): e("je .crl"):
    e("cmp r8b, 10"): e("je .crl"): e("jmp .drl"):
    el(".crl: dec rax"): e("jmp .srln"):
    el(".drl: mov byte [rsi+rax], 0"): e("mov rax, rsi"):
    e("lea rsp, [rbp-8]"): e("pop rsi"): e("pop rbp"): e("ret"):

    el("ig_str_to_int:"):
    e("push rbx"): e("push rsi"): e("mov rsi, rcx"):
    e("xor eax, eax"): e("xor r11d, r11d"):
    e("cmp byte [rsi], '-'"): e("jne .dsi"): e("mov r11d, 1"): e("inc rsi"):
    el(".dsi: xor ebx, ebx"):
    el(".lsi: movzx ecx, byte [rsi]"): e("test cl, cl"): e("jz .esi"):
    e("cmp cl, '0'"): e("jb ig_badnum"): e("cmp cl, '9'"): e("ja ig_badnum"):
    e("imul rax, rax, 10"): e("sub cl, '0'"): e("movzx ecx, cl"): e("add rax, rcx"):
    e("mov ebx, 1"): e("inc rsi"): e("jmp .lsi"):
    el(".esi: test ebx, ebx"): e("jz ig_badnum"):
    e("test r11d, r11d"): e("jz .psi"): e("neg rax"):
    el(".psi: pop rsi"): e("pop rbx"): e("ret"):

    el("ig_text_index:"):
    e("push rsi"): e("mov rsi, rcx"): e("call ig_strlen"):
    e("cmp rdx, rax"): e("jae ig_oob"):
    e("mov rcx, 2"): e("call ig_alloc"):
    e("mov r8b, [rsi+rdx]"): e("mov [rax], r8b"): e("mov byte [rax+1], 0"):
    e("pop rsi"): e("ret"):

    el("ig_chr:"):
    e("push rbx"): e("mov rbx, rcx"): e("mov ecx, 2"): e("call ig_alloc"):
    e("mov [rax], bl"): e("mov byte [rax+1], 0"): e("pop rbx"): e("ret"):

    el("ig_clock:"):
    e("push rbp"): e("mov rbp, rsp"): e("and rsp, -16"): e("sub rsp, 32"):
    e("call GetTickCount"): e("mov rsp, rbp"): e("pop rbp"): e("ret"):

    // ig_system(rcx=cmd) -> exit code; runs "cmd.exe /c <cmd>"
    // Uses CreateProcessA + WaitForSingleObject + GetExitCodeProcess (all in kernel32)
    el("ig_system:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("push rbx"): e("push rsi"): e("push rdi"):
    e("and rsp, -16"): e("sub rsp, 32"):  // align + permanent shadow space
    // Build "cmd.exe /c \"<command>\"" in heap buffer; rsi = original cmd, rbx = buffer start
    // Extra outer quotes so cmd.exe strips them and leaves inner path quotes intact.
    e("mov rsi, rcx"):
    e("call ig_strlen"): e("add rax, 14"):
    e("mov rcx, rax"): e("call ig_alloc"): e("mov rbx, rax"):
    e("mov rdi, rbx"):
    e("lea rcx, [ig_sys_prefix]"):
    el(".igscp: mov al, [rcx]"): e("test al, al"): e("jz .igscq"):
    e("mov [rdi], al"): e("inc rcx"): e("inc rdi"): e("jmp .igscp"):
    el(".igscq:"):
    e("mov rcx, rsi"):
    el(".igscm: mov al, [rcx]"): e("test al, al"): e("jz .igscn"):
    e("mov [rdi], al"): e("inc rcx"): e("inc rdi"): e("jmp .igscm"):
    el(".igscn: mov byte [rdi], 34"):  // closing '"' (ASCII 34)
    e("mov byte [rdi+1], 0"):
    // Allocate zeroed STARTUPINFOA (104 bytes) on heap; rsi = &si
    e("mov ecx, 104"): e("call ig_alloc"): e("mov rsi, rax"):
    e("xor r10, r10"):
    el(".igzi: cmp r10, 104"): e("jge .igzd"):
    e("mov byte [rsi+r10], 0"): e("inc r10"): e("jmp .igzi"):
    el(".igzd: mov dword [rsi], 104"):
    // Allocate zeroed PROCESS_INFORMATION (32 bytes) on heap; rdi = &pi
    e("mov ecx, 32"): e("call ig_alloc"): e("mov rdi, rax"):
    e("mov qword [rdi], 0"): e("mov qword [rdi+8], 0"):
    e("mov qword [rdi+16], 0"): e("mov qword [rdi+24], 0"):
    // CreateProcessA(NULL, cmdline, NULL, NULL, 0, 0, NULL, NULL, &si, &pi)
    e("sub rsp, 48"):       // space for args 5-10 (stack stays 16-aligned: 32+48=80)
    e("xor ecx, ecx"):      // arg1: lpApplicationName = NULL
    e("mov rdx, rbx"):      // arg2: lpCommandLine
    e("xor r8d, r8d"):      // arg3: lpProcessAttributes = NULL
    e("xor r9d, r9d"):      // arg4: lpThreadAttributes = NULL
    e("mov qword [rsp+32], 0"):  // arg5: bInheritHandles = FALSE
    e("mov qword [rsp+40], 0"):  // arg6: dwCreationFlags = 0
    e("mov qword [rsp+48], 0"):  // arg7: lpEnvironment = NULL
    e("mov qword [rsp+56], 0"):  // arg8: lpCurrentDirectory = NULL
    e("mov [rsp+64], rsi"):      // arg9: lpStartupInfo
    e("mov [rsp+72], rdi"):      // arg10: lpProcessInformation
    e("call CreateProcessA"):
    e("add rsp, 48"):
    e("test eax, eax"): e("jz .igsfail"):
    // WaitForSingleObject(pi.hProcess, INFINITE)
    e("mov rcx, [rdi]"): e("mov edx, -1"): e("call WaitForSingleObject"):
    // GetExitCodeProcess(pi.hProcess, &exitCode) — alloc 4-byte buffer
    e("mov ecx, 4"): e("call ig_alloc"): e("mov rbx, rax"):
    e("mov rcx, [rdi]"): e("mov rdx, rbx"): e("call GetExitCodeProcess"):
    e("mov eax, dword [rbx]"): e("jmp .igsdone"):
    el(".igsfail: mov eax, -1"):
    el(".igsdone:"):
    e("lea rsp, [rbp-24]"): e("pop rdi"): e("pop rsi"): e("pop rbx"): e("pop rbp"): e("ret"):

    el("ig_substr:"):
    e("push rsi"): e("push rdi"): e("push rbx"):
    e("mov rsi, rcx"): e("mov rdi, rdx"): e("mov rbx, r8"):
    e("call ig_strlen"):
    e("test rdi, rdi"): e("jns .ioks"): e("xor edi, edi"):
    el(".ioks: cmp rbx, rax"): e("jle .joks"): e("mov rbx, rax"):
    el(".joks: cmp rdi, rbx"): e("jle .roks"): e("mov rdi, rbx"):
    el(".roks: mov rcx, rbx"): e("sub rcx, rdi"): e("push rcx"):
    e("inc rcx"): e("call ig_alloc"): e("pop rcx"): e("xor r9d, r9d"):
    el(".cps: cmp r9, rcx"): e("je .zs"):
    e("mov r8b, [rsi+rdi]"): e("mov [rax+r9], r8b"):
    e("inc rdi"): e("inc r9"): e("jmp .cps"):
    el(".zs: mov byte [rax+r9], 0"):
    e("pop rbx"): e("pop rdi"): e("pop rsi"): e("ret"):

    el("ig_readfile:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("and rsp, -16"): e("sub rsp, 64"):
    e("mov rcx, rsi"): e("mov edx, 0x80000000"): e("mov r8d, 1"):
    e("xor r9d, r9d"): e("mov qword [rsp+32], 3"):
    e("mov qword [rsp+40], 0"): e("mov qword [rsp+48], 0"):
    e("call CreateFileA"): e("cmp rax, -1"): e("je ig_nofile"):
    e("mov rdi, rax"):
    e("mov rcx, rdi"): e("lea rdx, [fsize]"): e("call GetFileSizeEx"):
    e("mov rcx, [fsize]"): e("inc rcx"): e("call ig_alloc"): e("mov rsi, rax"):
    e("mov rcx, rdi"): e("mov rdx, rsi"): e("mov r8, [fsize]"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call ReadFile"):
    e("mov rax, [written]"): e("mov byte [rsi+rax], 0"):
    e("mov rcx, rdi"): e("call CloseHandle"):
    e("mov rax, rsi"): e("lea rsp, [rbp-16]"):
    e("pop rdi"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ===== streaming file reads (open/read-chunk/eof/close) =====

    // ig_file_open(rcx=path) -> rax = file handle (jumps to ig_nofile on failure)
    el("ig_file_open:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("and rsp, -16"): e("sub rsp, 64"):
    e("mov edx, 0x80000000"): e("mov r8d, 1"): e("xor r9d, r9d"):
    e("mov qword [rsp+32], 3"): e("mov qword [rsp+40], 0"): e("mov qword [rsp+48], 0"):
    e("call CreateFileA"): e("cmp rax, -1"): e("je ig_nofile"):
    e("mov rsp, rbp"): e("pop rbp"): e("ret"):

    // ig_file_read_chunk(rcx=handle, rdx=n) -> rax = text (up to n bytes; "" at EOF)
    el("ig_file_read_chunk:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rdi"): e("push rbx"):
    e("mov rsi, rcx"): e("mov rbx, rdx"):
    e("and rsp, -16"): e("sub rsp, 48"):
    e("lea rcx, [rbx+1]"): e("call ig_alloc"): e("mov rdi, rax"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("mov r8, rbx"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call ReadFile"):
    e("mov rax, [written]"): e("mov byte [rdi+rax], 0"):
    e("mov rax, rdi"):
    e("lea rsp, [rbp-24]"): e("pop rbx"): e("pop rdi"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ig_file_eof(rcx=handle) -> rax = 1 if the read position is at/past the file's end
    el("ig_file_eof:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"):
    e("mov rsi, rcx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov rcx, rsi"): e("lea rdx, [fsize]"): e("call GetFileSizeEx"):
    e("mov rcx, rsi"): e("xor edx, edx"): e("lea r8, [filepos]"): e("mov r9d, 1"): e("call SetFilePointerEx"):
    e("mov rax, [filepos]"): e("cmp rax, [fsize]"): e("jl .fne_no"):
    e("mov eax, 1"): e("jmp .fne_done"):
    el(".fne_no: xor eax, eax"):
    el(".fne_done: lea rsp, [rbp-8]"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ig_file_close(rcx=handle) -> rax = result
    el("ig_file_close:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("call CloseHandle"):
    e("mov rsp, rbp"): e("pop rbp"): e("ret"):

    // ig_getenv(rcx=name) -> rax = text (value, or "" if not set)
    el("ig_getenv:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rbx"):
    e("mov rsi, rcx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov ecx, 1024"): e("call ig_alloc"): e("mov rbx, rax"):
    e("mov rcx, rsi"): e("mov rdx, rbx"): e("mov r8d, 1024"):
    e("call GetEnvironmentVariableA"):
    e("test eax, eax"): e("jnz .igev_ok"):
    e("lea rax, [str_noerr]"): e("jmp .igev_done"):
    el(".igev_ok: mov rax, rbx"):
    el(".igev_done: lea rsp, [rbp-16]"): e("pop rbx"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ig_exedir() -> rax = text (directory containing the running .exe, no trailing '\')
    el("ig_exedir:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rbx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov ecx, 1024"): e("call ig_alloc"): e("mov rbx, rax"):
    e("xor ecx, ecx"): e("mov rdx, rbx"): e("mov r8d, 1024"):
    e("call GetModuleFileNameA"):
    e("mov rsi, rbx"): e("add rsi, rax"):
    el(".iged_scan: cmp rsi, rbx"): e("jle .iged_done"):
    e("dec rsi"): e("movzx eax, byte [rsi]"): e("cmp eax, 92"): e("jne .iged_scan"):
    e("mov byte [rsi], 0"): e("jmp .iged_done"):
    el(".iged_done: mov rax, rbx"):
    e("lea rsp, [rbp-16]"): e("pop rbx"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ===== cooperative coroutines (single-threaded stackful, ret-based switch) =====
    // Context block layout (1624 bytes, heap-allocated per coroutine):
    //   +0  saved_rsp      +8  saved_rbx      +16 saved_rbp
    //   +24 saved_rsi      +32 saved_rdi
    //   +40 saved_r12      +48 saved_r13      +56 saved_r14   +64 saved_r15
    //   +72 status (0=ready/yielded, 1=done)
    //   +80 saved g_exc_top
    //   +88  saved g_exc_rbp[64] (512B)  +600  saved g_exc_rsp[64] (512B)
    //   +1112 saved g_exc_tgt[64] (512B)                          (ends at 1624)
    // try/catch's exception-context stack is GLOBAL (g_exc_top/rbp/rsp/tgt), so it
    // must be swapped in/out here too, or two coroutines interleaving try/catch
    // would corrupt each other's exception state.

    // ig_coro_switch(rcx = target context block) -> saves the CURRENTLY running
    // context (whatever [coro_current] points to) and resumes `rcx`. Returns
    // (via `ret`, popping whatever the target last "called" this function from,
    // or its fresh bootstrap entry point for a brand new coroutine) when the
    // TARGET later switches back to whoever resumed it.
    el("ig_coro_switch:"):
    e("mov r10, [coro_current]"):
    e("mov [r10+0], rsp"): e("mov [r10+8], rbx"): e("mov [r10+16], rbp"):
    e("mov [r10+24], rsi"): e("mov [r10+32], rdi"):
    e("mov [r10+40], r12"): e("mov [r10+48], r13"): e("mov [r10+56], r14"): e("mov [r10+64], r15"):
    e("mov rax, [g_exc_top]"): e("mov [r10+80], rax"):
    e("lea rsi, [g_exc_rbp]"): e("lea rdi, [r10+88]"): e("mov r8d, 64"):
    el(".cs_s1: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_s1"):
    e("lea rsi, [g_exc_rsp]"): e("lea rdi, [r10+600]"): e("mov r8d, 64"):
    el(".cs_s2: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_s2"):
    e("lea rsi, [g_exc_tgt]"): e("lea rdi, [r10+1112]"): e("mov r8d, 64"):
    el(".cs_s3: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_s3"):

    e("mov [coro_current], rcx"):
    e("mov rax, [rcx+80]"): e("mov [g_exc_top], rax"):
    e("lea rsi, [rcx+88]"): e("lea rdi, [g_exc_rbp]"): e("mov r8d, 64"):
    el(".cs_r1: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_r1"):
    e("lea rsi, [rcx+600]"): e("lea rdi, [g_exc_rsp]"): e("mov r8d, 64"):
    el(".cs_r2: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_r2"):
    e("lea rsi, [rcx+1112]"): e("lea rdi, [g_exc_tgt]"): e("mov r8d, 64"):
    el(".cs_r3: mov rax, [rsi]"): e("mov [rdi], rax"): e("add rsi, 8"): e("add rdi, 8"): e("dec r8d"): e("jnz .cs_r3"):

    e("mov rsp, [rcx+0]"): e("mov rbx, [rcx+8]"): e("mov rbp, [rcx+16]"):
    e("mov rsi, [rcx+24]"): e("mov rdi, [rcx+32]"):
    e("mov r12, [rcx+40]"): e("mov r13, [rcx+48]"): e("mov r14, [rcx+56]"): e("mov r15, [rcx+64]"):
    e("ret"):

    // ig_coro_spawn(rcx = entry label address) -> registers a new coroutine
    // (fresh stack + context block) onto the ready queue. Does not run it yet.
    el("ig_coro_spawn:"):
    e("push rbx"): e("push rsi"):
    e("mov rbx, rcx"):
    e("mov ecx, 1624"): e("call ig_alloc"): e("mov rsi, rax"):
    e("mov ecx, 65536"): e("call ig_alloc"):
    e("lea rax, [rax+65536]"): e("sub rax, 8"): e("mov [rax], rbx"):
    e("mov [rsi+0], rax"):
    e("mov qword [rsi+8], 0"): e("mov qword [rsi+16], 0"):
    e("mov qword [rsi+24], 0"): e("mov qword [rsi+32], 0"):
    e("mov qword [rsi+40], 0"): e("mov qword [rsi+48], 0"):
    e("mov qword [rsi+56], 0"): e("mov qword [rsi+64], 0"):
    e("mov qword [rsi+72], 0"): e("mov qword [rsi+80], 0"):
    e("mov rax, [coro_ready]"): e("test rax, rax"): e("jnz .csp_havelist"):
    e("mov ecx, 8"): e("call ig_list_new"): e("mov [coro_ready], rax"):
    el(".csp_havelist:"):
    e("mov rcx, [coro_ready]"): e("mov rdx, rsi"): e("call ig_list_push"):
    e("pop rsi"): e("pop rbx"): e("ret"):

    // ig_coro_yield() -> suspend the running coroutine, switch back to the
    // scheduler; resumes here (i.e. this call returns) when this coroutine
    // gets its next turn.
    el("ig_coro_yield:"):
    e("mov rcx, [sched_ctx]"): e("call ig_coro_switch"): e("ret"):

    // ig_coro_finish() -> mark the running coroutine done and switch back to
    // the scheduler for good (never resumed again). Called instead of a normal
    // `ret` at every exit point of a function that uses `yield` anywhere.
    el("ig_coro_finish:"):
    e("mov r10, [coro_current]"): e("mov qword [r10+72], 1"):
    e("mov rcx, [sched_ctx]"): e("call ig_coro_switch"): e("ret"):

    // ig_run_coroutines() -> drains the ready queue, round-robin, until every
    // spawned coroutine has finished.
    el("ig_run_coroutines:"):
    e("push rbx"):
    e("mov ecx, 1624"): e("call ig_alloc"): e("mov rbx, rax"):
    e("mov [sched_ctx], rbx"): e("mov qword [rbx+72], 0"):
    e("mov [coro_current], rbx"):
    el(".rc_loop: mov rax, [coro_ready]"):
    e("test rax, rax"): e("jz .rc_done"):
    e("mov r10, [rax]"): e("test r10, r10"): e("jz .rc_done"):
    e("mov rcx, rax"): e("call ig_list_pop"): e("mov rbx, rax"):
    e("mov rcx, rbx"): e("call ig_coro_switch"):
    e("mov rax, [rbx+72]"): e("cmp rax, 1"): e("je .rc_loop"):
    e("mov rcx, [coro_ready]"): e("mov rdx, rbx"): e("call ig_list_push"):
    e("jmp .rc_loop"):
    el(".rc_done: pop rbx"): e("ret"):

    el("ig_writefile:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("mov rdi, rdx"):
    e("and rsp, -16"): e("sub rsp, 64"):
    e("mov rcx, rsi"): e("mov edx, 0x40000000"):
    e("xor r8d, r8d"): e("xor r9d, r9d"):
    e("mov qword [rsp+32], 2"): e("mov qword [rsp+40], 0"): e("mov qword [rsp+48], 0"):
    e("call CreateFileA"): e("cmp rax, -1"): e("je ig_nofile"):
    e("mov rsi, rax"):
    e("mov rcx, rdi"): e("call ig_strlen"): e("mov r8, rax"):
    e("mov rcx, rsi"): e("mov rdx, rdi"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call WriteFile"):
    e("mov rcx, rsi"): e("call CloseHandle"): e("mov eax, 1"):
    e("lea rsp, [rbp-16]"): e("pop rdi"): e("pop rsi"): e("pop rbp"): e("ret"):

    el("ig_list_new:"):
    e("push rbx"): e("push rsi"): e("mov rbx, rcx"):
    e("mov ecx, 24"): e("call ig_alloc"): e("mov rsi, rax"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"):
    e("mov qword [rsi], 0"): e("mov [rsi+8], rbx"): e("mov [rsi+16], rax"):
    e("mov rax, rsi"): e("pop rsi"): e("pop rbx"): e("ret"):

    el("ig_list_push:"):
    e("push rbx"): e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("mov rdi, rdx"): e("mov rax, [rsi]"):
    e("cmp rax, [rsi+8]"): e("jb .lpok"):
    e("mov rbx, [rsi+8]"): e("add rbx, rbx"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"):
    e("mov r10, [rsi+16]"): e("xor r9d, r9d"):
    el(".lpcpy: cmp r9, [rsi]"): e("je .lpdone"):
    e("mov r8, [r10+r9*8]"): e("mov [rax+r9*8], r8"): e("inc r9"): e("jmp .lpcpy"):
    el(".lpdone: mov [rsi+16], rax"): e("mov [rsi+8], rbx"): e("mov rax, [rsi]"):
    el(".lpok: mov r10, [rsi+16]"):
    e("mov [r10+rax*8], rdi"): e("inc rax"): e("mov [rsi], rax"):
    e("mov rax, rsi"): e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    el("ig_list_get:"):
    e("cmp rdx, [rcx]"): e("jae ig_oob"):
    e("mov r10, [rcx+16]"): e("mov rax, [r10+rdx*8]"): e("ret"):

    el("ig_list_set:"):
    e("cmp rdx, [rcx]"): e("jae ig_oob"):
    e("mov r10, [rcx+16]"): e("mov [r10+rdx*8], r8"): e("ret"):

    el("ig_list_pop:"):
    e("mov rax, [rcx]"): e("test rax, rax"): e("jz ig_empty"):
    e("dec rax"): e("mov [rcx], rax"):
    e("mov r10, [rcx+16]"): e("mov rax, [r10+rax*8]"): e("ret"):

    // Parse GetCommandLineA() into g_argv (a list of text), skipping argv[0] (the exe path).
    // Handles double-quoted tokens (spaces preserved inside quotes); splits on plain spaces otherwise.
    el("ig_init_argv:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("push rsi"): e("push rdi"): e("push rbx"): e("push r12"): e("push r13"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("call GetCommandLineA"): e("mov rsi, rax"):
    // skip argv[0]
    e("cmp byte [rsi], '\"'"): e("jne .ia_nq0"):
    e("inc rsi"):
    el(".ia_sq0: mov al, [rsi]"): e("test al, al"): e("je .ia_a0"):
    e("cmp al, '\"'"): e("je .ia_aq0"):
    e("inc rsi"): e("jmp .ia_sq0"):
    el(".ia_aq0: inc rsi"): e("jmp .ia_a0"):
    el(".ia_nq0: mov al, [rsi]"): e("test al, al"): e("je .ia_a0"):
    e("cmp al, ' '"): e("je .ia_a0"):
    e("inc rsi"): e("jmp .ia_nq0"):
    el(".ia_a0:"):
    e("mov ecx, 4"): e("call ig_list_new"): e("mov r12, rax"):
    el(".ia_ws: mov al, [rsi]"): e("test al, al"): e("je .ia_done"):
    e("cmp al, ' '"): e("jne .ia_tok"):
    e("inc rsi"): e("jmp .ia_ws"):
    el(".ia_tok: mov ecx, 256"): e("call ig_alloc"): e("mov rdi, rax"): e("mov r13, rax"):
    e("cmp byte [rsi], '\"'"): e("jne .ia_plain"):
    e("inc rsi"):
    el(".ia_qc: mov al, [rsi]"): e("test al, al"): e("je .ia_tend"):
    e("cmp al, '\"'"): e("je .ia_qend"):
    e("mov [rdi], al"): e("inc rdi"): e("inc rsi"): e("jmp .ia_qc"):
    el(".ia_qend: inc rsi"): e("jmp .ia_tend"):
    el(".ia_plain: mov al, [rsi]"): e("test al, al"): e("je .ia_tend"):
    e("cmp al, ' '"): e("je .ia_tend"):
    e("mov [rdi], al"): e("inc rdi"): e("inc rsi"): e("jmp .ia_plain"):
    el(".ia_tend: mov byte [rdi], 0"):
    e("mov rcx, r12"): e("mov rdx, r13"): e("call ig_list_push"): e("mov r12, rax"):
    e("jmp .ia_ws"):
    el(".ia_done: mov [g_argv], r12"):
    e("lea rsp, [rbp-40]"):
    e("pop r13"): e("pop r12"): e("pop rbx"): e("pop rdi"): e("pop rsi"):
    e("pop rbp"): e("ret"):

    // try/catch support: a stack of {rbp, rsp, catch-target} contexts.
    // ig_exc_push(rcx=catch target addr): save current frame + target as a new context.
    el("ig_exc_push:"):
    e("mov rax, [g_exc_top]"):
    e("lea r11, [g_exc_rbp]"): e("mov [r11 + rax*8], rbp"):
    e("lea r11, [g_exc_rsp]"): e("lea r10, [rsp+8]"): e("mov [r11 + rax*8], r10"):
    e("lea r11, [g_exc_tgt]"): e("mov [r11 + rax*8], rcx"):
    e("inc rax"): e("mov [g_exc_top], rax"): e("ret"):

    // ig_exc_pop(): discard the top context (try block completed without error).
    el("ig_exc_pop:"):
    e("mov rax, [g_exc_top]"): e("test rax, rax"): e("jz .iep_done"):
    e("dec rax"): e("mov [g_exc_top], rax"):
    el(".iep_done: ret"):

    // ===== minimal TCP sockets (ws2_32) — lazily calls WSAStartup on first use =====

    // ig_sock_listen(rcx=port) -> rax = listening socket handle (or 0-ish INVALID_SOCKET on failure)
    el("ig_sock_listen:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rbx"): e("push rsi"):
    e("mov ebx, ecx"):
    e("and rsp, -16"): e("sub rsp, 64"):
    e("mov ecx, 0x0202"): e("lea rdx, [wsadata]"): e("call WSAStartup"):
    e("mov ecx, 2"): e("mov edx, 1"): e("mov r8d, 6"): e("call socket"):
    e("mov rsi, rax"):
    e("mov word [rsp+32], 2"):
    e("mov ax, bx"): e("xchg al, ah"): e("mov word [rsp+34], ax"):
    e("mov dword [rsp+36], 0"): e("mov qword [rsp+40], 0"):
    e("mov rcx, rsi"): e("lea rdx, [rsp+32]"): e("mov r8d, 16"): e("call bind"):
    e("mov rcx, rsi"): e("mov edx, 8"): e("call listen"):
    e("mov rax, rsi"):
    e("lea rsp, [rbp-16]"): e("pop rsi"): e("pop rbx"): e("pop rbp"): e("ret"):

    // ig_sock_accept(rcx=listener) -> rax = client socket handle
    el("ig_sock_accept:"):
    e("push rbp"): e("mov rbp, rsp"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("xor edx, edx"): e("xor r8d, r8d"): e("call accept"):
    e("mov rsp, rbp"): e("pop rbp"): e("ret"):

    // ig_sock_recv(rcx=sock) -> rax = text (null-terminated; empty string on close/error)
    el("ig_sock_recv:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov ecx, 4096"): e("call ig_alloc"): e("mov rdi, rax"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("mov r8d, 4095"): e("xor r9d, r9d"): e("call recv"):
    e("cmp rax, 0"): e("jg .isr_ok"): e("xor eax, eax"):
    el(".isr_ok: mov byte [rdi + rax], 0"):
    e("mov rax, rdi"):
    e("lea rsp, [rbp-16]"): e("pop rdi"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ig_sock_send(rcx=sock, rdx=text) -> rax = bytes sent
    el("ig_sock_send:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("mov rdi, rdx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov rcx, rdi"): e("call ig_strlen"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("mov r8d, eax"): e("xor r9d, r9d"): e("call send"):
    e("lea rsp, [rbp-16]"): e("pop rdi"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ig_sock_close(rcx=sock) -> rax = result
    el("ig_sock_close:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"):
    e("mov rsi, rcx"):
    e("and rsp, -16"): e("sub rsp, 32"):
    e("mov rcx, rsi"): e("mov edx, 1"): e("call shutdown"):
    e("mov rcx, rsi"): e("call closesocket"):
    e("lea rsp, [rbp-8]"): e("pop rsi"): e("pop rbp"): e("ret"):

    // ===== minimal map (text-keyed, linear-scan association array) =====
    // header layout: [0]=count [8]=capacity [16]=keys_ptr [24]=values_ptr

    el("ig_map_new:"):
    e("push rbx"): e("push rsi"):
    e("mov ebx, ecx"): e("cmp rbx, 4"): e("jae .mn_capok"): e("mov ebx, 4"):
    el(".mn_capok: mov ecx, 32"): e("call ig_alloc"): e("mov rsi, rax"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"): e("mov [rsi+16], rax"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"): e("mov [rsi+24], rax"):
    e("mov qword [rsi], 0"): e("mov [rsi+8], rbx"): e("mov rax, rsi"):
    e("pop rsi"): e("pop rbx"): e("ret"):

    // ig_map_find(rcx=map, rdx=key) -> rax = index, or -1 if not found
    el("ig_map_find:"):
    e("push rbx"): e("push rsi"): e("push rdi"): e("push r12"):
    e("mov rsi, rcx"): e("mov rdi, rdx"): e("mov r12, [rsi+16]"): e("xor ebx, ebx"):
    el(".mf_loop: cmp rbx, [rsi]"): e("jae .mf_nf"):
    e("mov rcx, [r12 + rbx*8]"): e("mov rdx, rdi"): e("call ig_streq"):
    e("test eax, eax"): e("jnz .mf_found"):
    e("inc rbx"): e("jmp .mf_loop"):
    el(".mf_found: mov rax, rbx"): e("jmp .mf_done"):
    el(".mf_nf: mov rax, -1"):
    el(".mf_done: pop r12"): e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    // ig_map_set(rcx=map, rdx=key, r8=value) -> rax=map
    el("ig_map_set:"):
    e("push rbx"): e("push rsi"): e("push rdi"): e("push r12"): e("push r13"):
    e("mov rsi, rcx"): e("mov rdi, rdx"): e("mov r13, r8"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("call ig_map_find"):
    e("cmp rax, 0"): e("jl .ms_append"):
    e("mov r12, [rsi+24]"): e("mov [r12 + rax*8], r13"): e("jmp .ms_done"):
    el(".ms_append: mov rax, [rsi]"): e("cmp rax, [rsi+8]"): e("jb .ms_ok"):
    e("mov rbx, [rsi+8]"): e("add rbx, rbx"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"): e("mov r12, rax"):
    e("mov r8, [rsi+16]"): e("xor r9d, r9d"):
    el(".ms_ck: cmp r9, [rsi]"): e("je .ms_ckd"):
    e("mov r10, [r8 + r9*8]"): e("mov [r12 + r9*8], r10"): e("inc r9"): e("jmp .ms_ck"):
    el(".ms_ckd: mov [rsi+16], r12"):
    e("lea rcx, [rbx*8]"): e("call ig_alloc"): e("mov r12, rax"):
    e("mov r8, [rsi+24]"): e("xor r9d, r9d"):
    el(".ms_cv: cmp r9, [rsi]"): e("je .ms_cvd"):
    e("mov r10, [r8 + r9*8]"): e("mov [r12 + r9*8], r10"): e("inc r9"): e("jmp .ms_cv"):
    el(".ms_cvd: mov [rsi+24], r12"): e("mov [rsi+8], rbx"):
    el(".ms_ok: mov rax, [rsi]"):
    e("mov r12, [rsi+16]"): e("mov [r12 + rax*8], rdi"):
    e("mov r12, [rsi+24]"): e("mov [r12 + rax*8], r13"):
    e("inc rax"): e("mov [rsi], rax"):
    el(".ms_done: mov rax, rsi"):
    e("pop r13"): e("pop r12"): e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    // ig_map_get(rcx=map, rdx=key) -> rax=value ; jumps to ig_nokey if missing (catchable via try/catch)
    el("ig_map_get:"):
    e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("mov rdi, rdx"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("call ig_map_find"):
    e("cmp rax, 0"): e("jl ig_nokey"):
    e("mov r10, [rsi+24]"): e("mov rax, [r10 + rax*8]"):
    e("pop rdi"): e("pop rsi"): e("ret"):

    // ig_map_has(rcx=map, rdx=key) -> rax = 0/1
    el("ig_map_has:"):
    e("push rsi"): e("push rdi"):
    e("mov rsi, rcx"): e("mov rdi, rdx"):
    e("mov rcx, rsi"): e("mov rdx, rdi"): e("call ig_map_find"):
    e("cmp rax, 0"): e("jl .mh_no"): e("mov eax, 1"): e("jmp .mh_done"):
    el(".mh_no: xor eax, eax"):
    el(".mh_done: pop rdi"): e("pop rsi"): e("ret"):

    // ig_map_keys(rcx=map) -> rax = new list of text keys
    el("ig_map_keys:"):
    e("push rbx"): e("push rsi"): e("push rdi"): e("push r12"):
    e("mov rsi, rcx"):
    e("mov ecx, 4"): e("call ig_list_new"): e("mov rdi, rax"):
    e("mov rbx, [rsi+16]"): e("xor r12d, r12d"):
    el(".mk_loop: cmp r12, [rsi]"): e("je .mk_done"):
    e("mov rcx, rdi"): e("mov rdx, [rbx + r12*8]"): e("call ig_list_push"): e("mov rdi, rax"):
    e("inc r12"): e("jmp .mk_loop"):
    el(".mk_done: mov rax, rdi"):
    e("pop r12"): e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    // Print to stdout
    el("ig_print_str:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"):
    e("mov rsi, rcx"): e("xor edx, edx"):
    el(".pslen: cmp byte [rcx+rdx], 0"): e("je .psgo"):
    e("inc rdx"): e("jmp .pslen"):
    el(".psgo: and rsp, -16"): e("sub rsp, 48"):
    e("mov rcx, [stdout_h]"): e("mov r8, rdx"): e("mov rdx, rsi"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call WriteFile"):
    e("lea rsp, [rbp-8]"): e("pop rsi"): e("pop rbp"): e("ret"):

    // Print to stderr
    el("ig_print_err:"):
    e("push rbp"): e("mov rbp, rsp"): e("push rsi"):
    e("mov rsi, rcx"): e("xor edx, edx"):
    el(".pelen: cmp byte [rcx+rdx], 0"): e("je .pego"):
    e("inc rdx"): e("jmp .pelen"):
    el(".pego: and rsp, -16"): e("sub rsp, 48"):
    e("mov rcx, [stderr_h]"): e("mov r8, rdx"): e("mov rdx, rsi"):
    e("lea r9, [written]"): e("mov qword [rsp+32], 0"): e("call WriteFile"):
    e("lea rsp, [rbp-8]"): e("pop rsi"): e("pop rbp"): e("ret"):

    el("ig_print_int:"):
    e("push rbp"): e("push rbx"): e("mov rax, rcx"):
    e("lea r10, [numbuf+30]"): e("mov byte [r10], 0"): e("xor r11d, r11d"):
    e("test rax, rax"): e("jns .cpi"): e("neg rax"): e("mov r11d, 1"):
    el(".cpi: mov rbx, 10"):
    el(".dpi: xor edx, edx"): e("div rbx"):
    e("add dl, '0'"): e("dec r10"): e("mov [r10], dl"):
    e("test rax, rax"): e("jnz .dpi"):
    e("test r11d, r11d"): e("jz .opi"):
    e("dec r10"): e("mov byte [r10], '-'"):
    el(".opi: mov rcx, r10"): e("pop rbx"): e("pop rbp"): e("jmp ig_print_str"):

    el("ig_print_int_err:"):
    e("push rbp"): e("push rbx"): e("mov rax, rcx"):
    e("lea r10, [numbuf+30]"): e("mov byte [r10], 0"): e("xor r11d, r11d"):
    e("test rax, rax"): e("jns .cpie"): e("neg rax"): e("mov r11d, 1"):
    el(".cpie: mov rbx, 10"):
    el(".dpie: xor edx, edx"): e("div rbx"):
    e("add dl, '0'"): e("dec r10"): e("mov [r10], dl"):
    e("test rax, rax"): e("jnz .dpie"):
    e("test r11d, r11d"): e("jz .opie"):
    e("dec r10"): e("mov byte [r10], '-'"):
    el(".opie: mov rcx, r10"): e("pop rbx"): e("pop rbp"): e("jmp ig_print_err"):

    el("ig_print_list:"):
    e("push rbx"): e("push rsi"): e("push rdi"):
    e("mov rdi, rcx"): e("movzx ebx, dl"):
    e("lea rcx, [" + sref("{") + "]"): e("call ig_print_str"):
    e("xor esi, esi"):
    el(".lpll: cmp rsi, [rdi]"): e("je .endll"):
    e("test rsi, rsi"): e("jz .nocll"):
    e("lea rcx, [" + sref(", ") + "]"): e("call ig_print_str"):
    el(".nocll: mov r10, [rdi+16]"): e("mov rcx, [r10+rsi*8]"):
    e("test ebx, ebx"): e("jnz .sll"): e("call ig_print_int"): e("jmp .nxll"):
    el(".sll: call ig_print_str"):
    el(".nxll: inc rsi"): e("jmp .lpll"):
    el(".endll: lea rcx, [" + sref("}") + "]"): e("call ig_print_str"):
    e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    el("ig_print_list_err:"):
    e("push rbx"): e("push rsi"): e("push rdi"):
    e("mov rdi, rcx"): e("movzx ebx, dl"):
    e("lea rcx, [" + sref("{") + "]"): e("call ig_print_err"):
    e("xor esi, esi"):
    el(".lple: cmp rsi, [rdi]"): e("je .endle"):
    e("test rsi, rsi"): e("jz .nocle"):
    e("lea rcx, [" + sref(", ") + "]"): e("call ig_print_err"):
    el(".nocle: mov r10, [rdi+16]"): e("mov rcx, [r10+rsi*8]"):
    e("test ebx, ebx"): e("jnz .sle"): e("call ig_print_int_err"): e("jmp .nxle"):
    el(".sle: call ig_print_err"):
    el(".nxle: inc rsi"): e("jmp .lple"):
    el(".endle: lea rcx, [" + sref("}") + "]"): e("call ig_print_err"):
    e("pop rdi"): e("pop rsi"): e("pop rbx"): e("ret"):

    // Error handlers
    let list elabs = {"~"}:
    let list emsgs = {"~"}:
    push(elabs, "ig_div0"):   push(emsgs, "runtime error: division by zero"):
    push(elabs, "ig_oob"):    push(emsgs, "runtime error: index out of bounds"):
    push(elabs, "ig_empty"):  push(emsgs, "runtime error: pop() on empty list"):
    push(elabs, "ig_badnum"): push(emsgs, "runtime error: text is not a number"):
    push(elabs, "ig_oom"):    push(emsgs, "runtime error: out of memory"):
    push(elabs, "ig_nofile"): push(emsgs, "runtime error: cannot open file"):
    push(elabs, "ig_nokey"):  push(emsgs, "runtime error: map key not found"):
    let int ei = 1:
    loop while ei < len(elabs) [
        el(elabs{ei} + ":"):
        e("lea rcx, [" + sref(emsgs{ei}) + "]"): e("mov [g_last_error], rcx"):
        e("mov rax, [g_exc_top]"): e("test rax, rax"): e("jz .noh"):
        e("dec rax"): e("mov [g_exc_top], rax"):
        e("lea r11, [g_exc_rbp]"): e("mov rbp, [r11 + rax*8]"):
        e("lea r11, [g_exc_rsp]"): e("mov rsp, [r11 + rax*8]"):
        e("lea r11, [g_exc_tgt]"): e("mov r10, [r11 + rax*8]"):
        e("jmp r10"):
        el(".noh: lea rcx, [" + sref(emsgs{ei}) + "]"): e("call ig_print_err"):
        e("lea rcx, [str_nl]"): e("call ig_print_err"):
        e("and rsp, -16"): e("sub rsp, 32"):
        e("mov ecx, 1"): e("call ExitProcess"):
        ei = ei + 1:
    ]
    give 0:
]

// ---- emit data + bss sections ----
fn gen_data() -> int [
    el("section .data"):
    el("str_nl: db 13,10,0"):
    el("str_noerr: db 0"):
    el("str_dot: db \".\",0"):
    el("str_minus: db \"-\",0"):
    el("ig_sys_prefix: db 'cmd.exe /c \"',0"):
    el("dbl_scale: dq 1000000.0"):
    el("dbl_ten: dq 10.0"):
    let int i = 1:
    loop while i < len(str_vals) [
        iglog("str_" + totext(i - 1) + ": db " + str_to_db(str_vals{i})):
        i = i + 1:
    ]
    let int di = 1:
    loop while di < len(dbl_vals) [
        iglog("dbl_" + totext(di - 1) + ": dq " + dbl_vals{di}):
        di = di + 1:
    ]
    el("section .bss"):
    el("stdout_h: resq 1"): el("stderr_h: resq 1"): el("stdin_h: resq 1"):
    el("written: resq 1"): el("numbuf: resb 32"):
    el("fsize: resq 1"): el("heap_cur: resq 1"): el("heap_end: resq 1"): el("g_argv: resq 1"):
    el("g_exc_top: resq 1"): el("g_exc_rbp: resq 64"): el("g_exc_rsp: resq 64"): el("g_exc_tgt: resq 64"):
    el("g_last_error: resq 1"):
    el("wsadata: resb 512"):
    el("filepos: resq 1"):
    el("coro_ready: resq 1"): el("coro_current: resq 1"): el("sched_ctx: resq 1"):
    let int j = 1:
    loop while j < len(gvar_n) [ el("ig_g_" + gvar_n{j} + ": resq 1"): j = j + 1: ]
    give 0:
]

// ---- entry ----
start [
    iglog.err("Ignid IR file to compile: "):
    let text path = ask(""):
    let text src = readfile(path):
    load_lines(src):
    prescan():

    // Emit NASM header + startup stub
    el("default rel"):
    el("global ig_start"):
    el("extern GetStdHandle, WriteFile, ReadFile, ExitProcess, VirtualAlloc, CreateFileA, GetFileSizeEx, CloseHandle, GetTickCount, CreateProcessA, WaitForSingleObject, GetExitCodeProcess, GetCommandLineA, SetFilePointerEx, GetEnvironmentVariableA, GetModuleFileNameA, SetConsoleOutputCP, SetConsoleCP"):
    el("extern WSAStartup, WSAGetLastError, socket, bind, listen, accept, recv, send, closesocket, shutdown"):
    el("section .text"):
    el("ig_start:"):
    e("sub rsp, 40"):
    // String literals are UTF-8 in the source and emitted verbatim as bytes;
    // without this, WriteFile-to-console renders any non-ASCII byte sequence
    // (e.g. an em dash) as mojibake under the console's default legacy code
    // page. Harmless no-op if stdout/stdin aren't a real console (redirected
    // to a file/pipe) — return value intentionally ignored either way.
    e("mov ecx, 65001"): e("call SetConsoleOutputCP"):
    e("mov ecx, 65001"): e("call SetConsoleCP"):
    e("mov ecx, -11"): e("call GetStdHandle"): e("mov [stdout_h], rax"):
    e("mov ecx, -12"): e("call GetStdHandle"): e("mov [stderr_h], rax"):
    e("mov ecx, -10"): e("call GetStdHandle"): e("mov [stdin_h], rax"):
    e("xor ecx, ecx"): e("mov edx, 536870912"):
    e("mov r8d, 0x3000"): e("mov r9d, 4"):
    e("call VirtualAlloc"): e("test rax, rax"): e("jz ig_oom"):
    e("mov [heap_cur], rax"):
    e("lea r10, [rax+67108864]"): e("mov [heap_end], r10"):
    e("lea r10, [str_noerr]"): e("mov [g_last_error], r10"):
    e("call ig_init_argv"):
    e("call ig_user_main"):
    e("xor ecx, ecx"): e("call ExitProcess"):

    // Find main block boundaries (search from line 1 — globals may appear between fns)
    let int nlines = len(lines):
    let int main_lo = 0: let int main_hi = 0:
    let int si = 1:
    loop while si < nlines [
        when lines{si} == "main" [
            let int mhi = si + 1:
            loop while mhi < nlines and lines{mhi} != "end" [ mhi = mhi + 1: ]
            main_lo = si: main_hi = mhi: stop:
        ]
        si = si + 1:
    ]
    // Emit user_main FIRST so global types are populated before functions.
    // pre_hi = main_lo covers ALL inline code including globals between fn blocks.
    let int pre_hi_gm = main_lo:
    when main_lo == 0 [ pre_hi_gm = nlines: ]
    gen_main(1, pre_hi_gm, main_lo, main_hi):
    // Now emit all functions (global types are now correct)
    let int i = 1:
    loop while i < nlines [
        let text line = lines{i}:
        when starts_with(line, "fn ") [
            let int fhi = i + 1:
            loop while fhi < nlines and lines{fhi} != "end" [
                when starts_with(lines{fhi}, "fn ") or lines{fhi} == "main" [ stop: ]
                fhi = fhi + 1:
            ]
            gen_fn(i, fhi): i = fhi + 1: skip:
        ]
        i = i + 1:
    ]

    gen_runtime():
    gen_data():
]
