// std.ig — Ignid Standard Library v1.0
// Usage: use "d:/Ignid/std.ig":

// ===== CHARACTER CLASSIFICATION =====

fn is_space(text ch) -> int [
    when ch == " " or ch == "\t" or ch == "\n" or ch == "\r" [ give 1: ]
    give 0:
]

fn is_upper_c(text ch) -> int [
    let int c = ord(ch):
    when c >= 65 and c <= 90 [ give 1: ]
    give 0:
]

fn is_lower_c(text ch) -> int [
    let int c = ord(ch):
    when c >= 97 and c <= 122 [ give 1: ]
    give 0:
]

fn is_alpha_c(text ch) -> int [
    when is_upper_c(ch) == 1 [ give 1: ]
    when is_lower_c(ch) == 1 [ give 1: ]
    give 0:
]

fn is_digit_c(text ch) -> int [
    let int c = ord(ch):
    when c >= 48 and c <= 57 [ give 1: ]
    give 0:
]

fn is_alnum_c(text ch) -> int [
    when is_alpha_c(ch) == 1 [ give 1: ]
    when is_digit_c(ch) == 1 [ give 1: ]
    give 0:
]

// ===== STRING OPERATIONS =====

fn ltrim(text s) -> text [
    let int i = 0: let int n = len(s):
    let int ltdone = 0:
    loop while ltdone == 0 [
        when i >= n [ ltdone = 1: stop: ]
        when is_space(s{i}) == 0 [ ltdone = 1: stop: ]
        i = i + 1:
    ]
    give sub(s, i, n):
]

fn rtrim(text s) -> text [
    let int n = len(s): let int i = n - 1:
    let int rtdone = 0:
    loop while rtdone == 0 [
        when i < 0 [ rtdone = 1: stop: ]
        when is_space(s{i}) == 0 [ rtdone = 1: stop: ]
        i = i - 1:
    ]
    give sub(s, 0, i + 1):
]

fn trim(text s) -> text [ give ltrim(rtrim(s)): ]

fn upper(text s) -> text [
    let text result = "":
    let int i = 0: let int n = len(s):
    loop while i < n [
        let int c = ord(s{i}):
        when c >= 97 and c <= 122 [ result = result + chr(c - 32): ]
        else [ result = result + s{i}: ]
        i = i + 1:
    ]
    give result:
]

fn lower(text s) -> text [
    let text result = "":
    let int i = 0: let int n = len(s):
    loop while i < n [
        let int c = ord(s{i}):
        when c >= 65 and c <= 90 [ result = result + chr(c + 32): ]
        else [ result = result + s{i}: ]
        i = i + 1:
    ]
    give result:
]

fn find(text s, text needle) -> int [
    let int sn = len(s): let int nn = len(needle):
    when nn == 0 [ give 0: ]
    when nn > sn [ give -1: ]
    let int i = 0:
    loop while i <= sn - nn [
        when sub(s, i, i + nn) == needle [ give i: ]
        i = i + 1:
    ]
    give -1:
]

fn starts_with(text s, text prefix) -> int [
    let int pn = len(prefix):
    when len(s) < pn [ give 0: ]
    when sub(s, 0, pn) == prefix [ give 1: ]
    give 0:
]

fn ends_with(text s, text suffix) -> int [
    let int sn = len(s): let int un = len(suffix):
    when sn < un [ give 0: ]
    when sub(s, sn - un, sn) == suffix [ give 1: ]
    give 0:
]

fn contains_str(text s, text needle) -> int [
    when find(s, needle) >= 0 [ give 1: ]
    give 0:
]

fn replace(text s, text old, text new_s) -> text [
    let text result = "":
    let int sn = len(s): let int on = len(old):
    when on == 0 [ give s: ]
    let int i = 0:
    loop while i < sn [
        when i + on <= sn and sub(s, i, i + on) == old [
            result = result + new_s:
            i = i + on:
        ]
        else [
            result = result + s{i}:
            i = i + 1:
        ]
    ]
    give result:
]

fn split(text s, text sep) -> list [
    let list result = {}:
    let int sn = len(s): let int sepn = len(sep):
    when sepn == 0 [ push(result, s): give result: ]
    let int i = 0: let int seg = 0:
    loop while i < sn [
        when i + sepn <= sn and sub(s, i, i + sepn) == sep [
            push(result, sub(s, seg, i)):
            i = i + sepn:
            seg = i:
        ]
        else [ i = i + 1: ]
    ]
    push(result, sub(s, seg, sn)):
    give result:
]

fn join(list words, text sep) -> text [
    let int n = len(words):
    when n == 0 [ give "": ]
    let text result = words{0}:
    let int i = 1:
    loop while i < n [
        result = result + sep + words{i}:
        i = i + 1:
    ]
    give result:
]

fn repeat(text s, int n) -> text [
    let text result = "":
    let int i = 0:
    loop while i < n [ result = result + s: i = i + 1: ]
    give result:
]

fn str_count(text s, text ch) -> int [
    let int count = 0: let int i = 0: let int n = len(s): let int cn = len(ch):
    loop while i + cn <= n [
        when sub(s, i, i + cn) == ch [
            count = count + 1:
            i = i + cn:
        ]
        else [ i = i + 1: ]
    ]
    give count:
]

fn reverse_str(text s) -> text [
    let text result = "":
    let int i = len(s) - 1:
    loop while i >= 0 [ result = result + s{i}: i = i - 1: ]
    give result:
]

fn pad_left(text s, int n, text ch) -> text [
    let text result = s:
    loop while len(result) < n [ result = ch + result: ]
    give result:
]

fn pad_right(text s, int n, text ch) -> text [
    let text result = s:
    loop while len(result) < n [ result = result + ch: ]
    give result:
]

fn str_lt(text a, text b) -> int [
    let int na = len(a): let int nb = len(b): let int i = 0:
    loop while i < na and i < nb [
        let int ca = ord(a{i}): let int cb = ord(b{i}):
        when ca < cb [ give 1: ]
        when ca > cb [ give 0: ]
        i = i + 1:
    ]
    when na < nb [ give 1: ]
    give 0:
]

fn str_gt(text a, text b) -> int [ give str_lt(b, a): ]

fn str_eq(text a, text b) -> int [
    when a == b [ give 1: ]
    give 0:
]

// ===== LIST OPERATIONS =====

// Prefer this over `let list x = {}:` when the list will hold text and you plan to
// index/print its elements directly. An empty `{}` literal has no way to know its
// intended element type and defaults to being read back as int; a list returned from
// a function (like this one) is correctly tagged as text. See KNOWN_ISSUES.md.
fn list_new_text() -> list [ give {}: ]

fn list_has(list l, text val) -> int [
    loop i in l [ when i == val [ give 1: ] ]
    give 0:
]

fn list_find(list l, text val) -> int [
    let int i = 0: let int n = len(l):
    loop while i < n [
        when l{i} == val [ give i: ]
        i = i + 1:
    ]
    give -1:
]

fn list_reverse(list l) -> list [
    let list result = {}:
    let int i = len(l) - 1:
    loop while i >= 0 [ push(result, l{i}): i = i - 1: ]
    give result:
]

fn list_slice(list l, int sl, int el) -> list [
    let list result = {}:
    let int n = len(l): let int i = sl:
    loop while i < el and i < n [ push(result, l{i}): i = i + 1: ]
    give result:
]

fn list_remove(list l, int idx) -> list [
    let list result = {}:
    let int i = 0: let int n = len(l):
    loop while i < n [
        when i != idx [ push(result, l{i}): ]
        i = i + 1:
    ]
    give result:
]

fn list_concat(list a, list b) -> list [
    let list result = {}:
    loop i in a [ push(result, i): ]
    loop i in b [ push(result, i): ]
    give result:
]

fn sort_str(list l) -> list [
    let int n = len(l): let list r = {}: let int ci = 0:
    loop while ci < n [ push(r, l{ci}): ci = ci + 1: ]
    let int j = 1:
    loop while j < n [
        let text key = r{j}: let int k = j - 1: let int ssdone = 0:
        loop while ssdone == 0 [
            when k < 0 [ ssdone = 1: stop: ]
            when str_lt(key, r{k}) == 0 [ ssdone = 1: stop: ]
            r{k + 1} = r{k}:
            k = k - 1:
        ]
        r{k + 1} = key:
        j = j + 1:
    ]
    give r:
]

fn sort_int(list l) -> list [
    let int n = len(l): let list r = {}: let int ci = 0:
    loop while ci < n [ push(r, l{ci}): ci = ci + 1: ]
    let int j = 1:
    loop while j < n [
        let int key = r{j}: let int k = j - 1: let int sidone = 0:
        loop while sidone == 0 [
            when k < 0 [ sidone = 1: stop: ]
            when key >= r{k} [ sidone = 1: stop: ]
            r{k + 1} = r{k}:
            k = k - 1:
        ]
        r{k + 1} = key:
        j = j + 1:
    ]
    give r:
]

// ===== MATH =====

fn pow(int base, int exp) -> int [
    when exp <= 0 [ give 1: ]
    let int result = 1: let int b = base: let int e = exp:
    loop while e > 0 [
        when e % 2 == 1 [ result = result * b: ]
        b = b * b:
        e = e / 2:
    ]
    give result:
]

fn sqrt_int(int n) -> int [
    when n <= 0 [ give 0: ]
    let int x = n: let int y = (x + 1) / 2:
    loop while y < x [
        x = y:
        y = (x + n / x) / 2:
    ]
    give x:
]

fn gcd(int a, int b) -> int [
    when a < 0 [ a = -a: ]
    when b < 0 [ b = -b: ]
    loop while b != 0 [
        let int t = b:
        b = a % b:
        a = t:
    ]
    give a:
]

fn lcm(int a, int b) -> int [
    when a == 0 or b == 0 [ give 0: ]
    give abs(a) / gcd(a, b) * abs(b):
]

fn is_prime(int n) -> int [
    when n < 2 [ give 0: ]
    when n == 2 [ give 1: ]
    when n % 2 == 0 [ give 0: ]
    let int i = 3:
    loop while i * i <= n [
        when n % i == 0 [ give 0: ]
        i = i + 2:
    ]
    give 1:
]

fn clamp(int v, int lo, int hi) -> int [
    when v < lo [ give lo: ]
    when v > hi [ give hi: ]
    give v:
]

fn sign(int x) -> int [
    when x > 0 [ give 1: ]
    when x < 0 [ give -1: ]
    give 0:
]

// ===== RANDOM (LCG, seed with rand_seed(clock())) =====

let int ig_rand_s = 2463534242:

fn rand_seed(int s) -> int [ ig_rand_s = s: give 0: ]

fn rand_next() -> int [
    ig_rand_s = ig_rand_s * 1664525 + 1013904223:
    give abs(ig_rand_s):
]

fn rand_int(int lo, int hi) -> int [
    when hi <= lo [ give lo: ]
    give lo + rand_next() % (hi - lo):
]

fn rand_bool() -> int [ give rand_next() % 2: ]

fn rand_float_pct() -> int [
    give rand_next() % 101:
]

// ===== I/O HELPERS =====

fn read_lines(text path) -> list [
    give split(readfile(path), "\n"):
]

fn write_lines(list lines, text path) -> int [
    give writefile(path, join(lines, "\n")):
]
