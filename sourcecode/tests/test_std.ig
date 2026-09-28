// test_std.ig — comprehensive tests for std.ig
use "d:/Ignid/std.ig":

fn assert_eq(text label, text got, text expect) -> int [
    when got == expect [
        iglog("  PASS: " + label):
        give 0:
    ]
    iglog("  FAIL: " + label + " got=" + got + " want=" + expect):
    give 1:
]

fn assert_int(text label, int got, int expect) -> int [
    when got == expect [
        iglog("  PASS: " + label):
        give 0:
    ]
    iglog("  FAIL: " + label + " got=" + totext(got) + " want=" + totext(expect)):
    give 1:
]

start [
    let int fails = 0:

    // ===== CHAR BUILTINS =====
    iglog("--- char builtins ---"):
    fails = fails + assert_int("ord A",  ord("A"), 65):
    fails = fails + assert_int("ord a",  ord("a"), 97):
    fails = fails + assert_int("ord 0",  ord("0"), 48):
    fails = fails + assert_eq ("chr 65", chr(65),  "A"):
    fails = fails + assert_eq ("chr 97", chr(97),  "a"):
    fails = fails + assert_eq ("chr 48", chr(48),  "0"):

    // ===== CHAR CLASSIFICATION =====
    iglog("--- char classification ---"):
    fails = fails + assert_int("is_space sp",  is_space(" "),  1):
    fails = fails + assert_int("is_space A",   is_space("A"),  0):
    fails = fails + assert_int("is_upper_c A", is_upper_c("A"), 1):
    fails = fails + assert_int("is_upper_c a", is_upper_c("a"), 0):
    fails = fails + assert_int("is_lower_c z", is_lower_c("z"), 1):
    fails = fails + assert_int("is_lower_c Z", is_lower_c("Z"), 0):
    fails = fails + assert_int("is_digit_c 5", is_digit_c("5"), 1):
    fails = fails + assert_int("is_digit_c a", is_digit_c("a"), 0):
    fails = fails + assert_int("is_alpha_c M", is_alpha_c("M"), 1):
    fails = fails + assert_int("is_alnum_c 3", is_alnum_c("3"), 1):
    fails = fails + assert_int("is_alnum_c !", is_alnum_c("!"), 0):

    // ===== STRING OPERATIONS =====
    iglog("--- string ops ---"):
    fails = fails + assert_eq("upper",  upper("hello World"), "HELLO WORLD"):
    fails = fails + assert_eq("lower",  lower("HELLO World"), "hello world"):
    fails = fails + assert_eq("trim",   trim("  hello  "),   "hello"):
    fails = fails + assert_eq("ltrim",  ltrim("  hi"),       "hi"):
    fails = fails + assert_eq("rtrim",  rtrim("hi  "),       "hi"):
    fails = fails + assert_eq("trim empty", trim("   "),     ""):

    fails = fails + assert_int("find hit",   find("hello world", "world"), 6):
    fails = fails + assert_int("find miss",  find("hello", "xyz"), -1):
    fails = fails + assert_int("find empty", find("hello", ""), 0):

    fails = fails + assert_int("starts_with 1", starts_with("hello", "hel"), 1):
    fails = fails + assert_int("starts_with 0", starts_with("hello", "ell"), 0):
    fails = fails + assert_int("ends_with 1",   ends_with("hello", "llo"), 1):
    fails = fails + assert_int("ends_with 0",   ends_with("hello", "hel"), 0):
    fails = fails + assert_int("contains_str 1",contains_str("hello world","world"), 1):
    fails = fails + assert_int("contains_str 0",contains_str("hello","xyz"), 0):

    fails = fails + assert_eq("replace",     replace("aabbaa", "aa", "X"), "XbbX"):
    fails = fails + assert_eq("replace none",replace("hello", "z", "!"), "hello"):

    fails = fails + assert_eq("repeat",   repeat("ab", 3), "ababab"):
    fails = fails + assert_eq("repeat 0", repeat("ab", 0), ""):

    fails = fails + assert_int("str_count a", str_count("banana", "a"), 3):
    fails = fails + assert_int("str_count x", str_count("banana", "x"), 0):

    fails = fails + assert_eq("reverse_str", reverse_str("hello"), "olleh"):
    fails = fails + assert_eq("pad_left",    pad_left("5", 3, "0"), "005"):
    fails = fails + assert_eq("pad_right",   pad_right("5", 3, "0"), "500"):

    fails = fails + assert_int("str_lt ab<bc", str_lt("ab", "bc"), 1):
    fails = fails + assert_int("str_lt bc<ab", str_lt("bc", "ab"), 0):
    fails = fails + assert_int("str_lt eq",    str_lt("ab", "ab"), 0):
    fails = fails + assert_int("str_lt short", str_lt("a",  "ab"), 1):
    fails = fails + assert_int("str_gt bc>ab", str_gt("bc", "ab"), 1):

    // split / join
    let list parts = split("a,b,c", ","):
    fails = fails + assert_int("split len", len(parts), 3):
    fails = fails + assert_eq("split[0]", parts{0}, "a"):
    fails = fails + assert_eq("split[1]", parts{1}, "b"):
    fails = fails + assert_eq("split[2]", parts{2}, "c"):
    fails = fails + assert_eq("join", join(parts, "-"), "a-b-c"):
    fails = fails + assert_eq("join empty", join({}, ","), ""):

    // split on missing sep -> whole string
    let list one = split("hello", ","):
    fails = fails + assert_int("split no sep len", len(one), 1):
    fails = fails + assert_eq("split no sep[0]", one{0}, "hello"):

    // ===== LIST OPERATIONS =====
    iglog("--- list ops ---"):
    let list words = {}:
    push(words, "banana"): push(words, "apple"):
    push(words, "cherry"): push(words, "date"):

    fails = fails + assert_int("list_has hit",  list_has(words, "apple"),  1):
    fails = fails + assert_int("list_has miss", list_has(words, "mango"),  0):
    fails = fails + assert_int("list_find hit", list_find(words, "cherry"),2):
    fails = fails + assert_int("list_find miss",list_find(words, "mango"), -1):

    let list rev = list_reverse(words):
    fails = fails + assert_eq("list_reverse[0]", rev{0}, "date"):
    fails = fails + assert_eq("list_reverse[3]", rev{3}, "banana"):

    let list sl = list_slice(words, 1, 3):
    fails = fails + assert_int("list_slice len", len(sl), 2):
    fails = fails + assert_eq("list_slice[0]",   sl{0}, "apple"):
    fails = fails + assert_eq("list_slice[1]",   sl{1}, "cherry"):

    let list rm = list_remove(words, 1):
    fails = fails + assert_int("list_remove len", len(rm), 3):
    fails = fails + assert_eq("list_remove[1]",   rm{1}, "cherry"):

    let list la = {}: push(la, "x"): push(la, "y"):
    let list lb = {}: push(lb, "a"): push(lb, "b"):
    let list cat = list_concat(la, lb):
    fails = fails + assert_int("list_concat len",  len(cat), 4):
    fails = fails + assert_eq("list_concat[2]",    cat{2}, "a"):

    // sort_str
    let list uw = {}:
    push(uw, "banana"): push(uw, "apple"):
    push(uw, "cherry"): push(uw, "date"):
    let list sorted = sort_str(uw):
    fails = fails + assert_eq("sort_str[0]", sorted{0}, "apple"):
    fails = fails + assert_eq("sort_str[1]", sorted{1}, "banana"):
    fails = fails + assert_eq("sort_str[2]", sorted{2}, "cherry"):
    fails = fails + assert_eq("sort_str[3]", sorted{3}, "date"):

    // sort_int
    let list nums = {}:
    push(nums, 5): push(nums, 2): push(nums, 8): push(nums, 1): push(nums, 9):
    let list snum = sort_int(nums):
    fails = fails + assert_int("sort_int[0]", snum{0}, 1):
    fails = fails + assert_int("sort_int[1]", snum{1}, 2):
    fails = fails + assert_int("sort_int[2]", snum{2}, 5):
    fails = fails + assert_int("sort_int[3]", snum{3}, 8):
    fails = fails + assert_int("sort_int[4]", snum{4}, 9):

    // ===== MATH =====
    iglog("--- math ---"):
    fails = fails + assert_int("pow 2^10",   pow(2, 10),  1024):
    fails = fails + assert_int("pow 3^0",    pow(3, 0),   1):
    fails = fails + assert_int("pow 5^3",    pow(5, 3),   125):
    fails = fails + assert_int("sqrt 25",    sqrt_int(25),  5):
    fails = fails + assert_int("sqrt 26",    sqrt_int(26),  5):
    fails = fails + assert_int("sqrt 0",     sqrt_int(0),   0):
    fails = fails + assert_int("gcd 12 8",   gcd(12, 8),    4):
    fails = fails + assert_int("gcd 7 13",   gcd(7, 13),    1):
    fails = fails + assert_int("gcd neg",    gcd(-6, 4),    2):
    fails = fails + assert_int("lcm 4 6",    lcm(4, 6),    12):
    fails = fails + assert_int("is_prime 2",  is_prime(2),  1):
    fails = fails + assert_int("is_prime 7",  is_prime(7),  1):
    fails = fails + assert_int("is_prime 1",  is_prime(1),  0):
    fails = fails + assert_int("is_prime 9",  is_prime(9),  0):
    fails = fails + assert_int("clamp lo",   clamp(-5, 0, 10), 0):
    fails = fails + assert_int("clamp hi",   clamp(15, 0, 10), 10):
    fails = fails + assert_int("clamp mid",  clamp(5,  0, 10), 5):
    fails = fails + assert_int("sign pos",   sign(7),   1):
    fails = fails + assert_int("sign neg",   sign(-3), -1):
    fails = fails + assert_int("sign zero",  sign(0),   0):

    // ===== RANDOM =====
    iglog("--- random ---"):
    let int tick = clock():
    rand_seed(tick):
    let int r1 = rand_int(1, 7):
    let int r2 = rand_int(0, 100):
    let int rb = rand_bool():
    fails = fails + assert_int("rand_int range lo", r1 >= 1, 1):
    fails = fails + assert_int("rand_int range hi", r1 <= 6, 1):
    fails = fails + assert_int("rand_int 100 lo",  r2 >= 0, 1):
    fails = fails + assert_int("rand_int 100 hi",  r2 <= 99, 1):
    fails = fails + assert_int("rand_bool lo",  rb >= 0, 1):
    fails = fails + assert_int("rand_bool hi",  rb <= 1, 1):

    // ===== PRINT BUILTINS =====
    iglog("--- print/println ---"):
    print("print: "):
    print("no"):
    print("newline"):
    println(""):
    println("println: has newline"):

    // ===== SUMMARY =====
    iglog(""):
    when fails == 0 [ iglog("ALL TESTS PASSED"): ]
    else [
        let text fs = totext(fails):
        iglog("FAILED: ${fs} test(s)"):
    ]
]
