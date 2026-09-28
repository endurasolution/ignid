// demo.ig — full tour of Ignid: language constructs + stdlib
use "d:/Ignid/std.ig":
use "d:/Ignid/demos/demo2.ig":   // pulls in appname(), appversion(), Account + its "methods"

enum Color [ Red: Green: Blue: ]

fn color_name(Color c) -> text [
    match c [
        Color.Red   [ give "red": ]
        Color.Green [ give "green": ]
        else        [ give "blue": ]
    ]
]

fn name() -> text [
    let int a = 5 :
    let int b = 1 + a:
    let int c = 2 :
    
]

fn person(text name, int age) -> text [
    give name + " is " + totext(age) + " years old":
]

start [
    iglog("== " + appname() + " v" + appversion() + " =="):

    let text result = person("GPU", 20):
    iglog(result):
    // variables + text
    let text name = "World":
    iglog("Hello, " + name + "!"):

    let any x = 42: iglog("x =", x):  // any type

    // arithmetic
    let int a = 6: let int b = 7:
    iglog(a, "*", b, "=", a * b):


    try [
        let int z = a / 0:  // divide by zero
        iglog("z =", z):
    ]
    catch [
        iglog("caught error:", lasterror()):
    ]


    // list + join
    let list colors = {}:
    push(colors, "red"): push(colors, "green"): push(colors, "blue"):
    iglog("Colors:", join(colors, ", ")):

    // if / elif / else  ->  "when / or / else" in Ignid
    let int score = 72:
    when score >= 90 [ iglog("Grade: A"): ]
    or score >= 70   [ iglog("Grade: B"): ]
    or score >= 50   [ iglog("Grade: C"): ]
    else             [ iglog("Grade: F"): ]

    // for loop  ->  "loop VAR in LOW to HIGH"
    let text line = "":
    loop i in 1 to 5 [ line = line + totext(i) + " ": ]
    iglog("Counting:", line):

    // while loop  ->  "loop while COND"
    let int n = 5:
    loop while n > 0 [
        iglog("countdown:", n):
        n = n - 1:
    ]
    iglog("liftoff!"):

    // class-style usage: rec + "methods" (functions that take the instance)
    let Account acc = new_account("Alice", 100):
    iglog(describe(acc)):
    deposit(acc, 50):
    iglog("after deposit(50):", describe(acc)):

    // ===== fix (constants) =====
    fix PI = 3:
    iglog("fix PI =", PI):

    // ===== enum + match =====
    let Color c = Color.Green:
    iglog("Color.Green =", c, "->", color_name(c)):
    match c [
        Color.Red   [ iglog("it's red"): ]
        Color.Green [ iglog("it's green"): ]
        else        [ iglog("it's something else"): ]
    ]

    // ===== string interpolation =====
    let int x = 7: let int y = 3:
    let int xy_sum = x + y:
    iglog("interpolation: x=${x}, y=${y}, x+y=${xy_sum}"):

    // ===== string functions (std.ig) =====
    iglog("-- string functions --"):
    iglog("upper:", upper("hello")):
    iglog("lower:", lower("WORLD")):
    iglog("starts_with 'hello','he':", starts_with("hello", "he")):
    iglog("ends_with 'hello','lo':", ends_with("hello", "lo")):
    iglog("contains_str 'hello','ell':", contains_str("hello", "ell")):
    iglog("replace 'foo bar foo','foo','baz':", replace("foo bar foo", "foo", "baz")):
    iglog("pad_left '7' to 3 with '0':", pad_left("7", 3, "0")):
    iglog("pad_right 'hi' to 5 with '.':", pad_right("hi", 5, ".")):
    iglog("repeat 'ab',3:", repeat("ab", 3)):
    iglog("str_count 'banana','a':", str_count("banana", "a")):
    iglog("reverse_str 'abcde':", reverse_str("abcde")):
    iglog("str_lt 'a','b':", str_lt("a", "b"), " str_eq 'x','x':", str_eq("x", "x")):
    iglog("sub('hello world', 6, 11):", sub("hello world", 6, 11)):

    // ===== list functions (std.ig) =====
    // note: list_has/list_find are text-only (see their `text val` param in std.ig),
    // so they're demoed on `colors` (text) rather than an int list.
    iglog("-- list functions --"):
    iglog("colors has 'green':", list_has(colors, "green")):
    iglog("list_find colors,'blue':", list_find(colors, "blue")):
    let list rev = list_reverse(colors):
    iglog("reversed colors:", join(rev, ", ")):

    let list nums = {}:
    push(nums, 3): push(nums, 1): push(nums, 4): push(nums, 1): push(nums, 5):
    let list nsort = sort_int(nums):
    let text nsort_str = "": let int ni = 0:
    loop while ni < len(nsort) [
        nsort_str = nsort_str + totext(nsort{ni}) + " ":
        ni = ni + 1:
    ]
    iglog("sorted ints:", nsort_str):

    let list sl = list_slice(colors, 0, 2):
    iglog("slice colors[0:2]:", join(sl, ", ")):
    let list rm = list_remove(colors, 1):
    iglog("removed idx1 from colors:", join(rm, ", ")):
    let list cat = list_concat(colors, rm):
    iglog("concat colors+rm:", join(cat, ", ")):

    // ===== math functions (std.ig) =====
    iglog("-- math functions --"):
    iglog("pow(2,10):", pow(2, 10)):
    iglog("sqrt_int(50):", sqrt_int(50)):
    iglog("gcd(24,36):", gcd(24, 36)):
    iglog("lcm(4,6):", lcm(4, 6)):
    iglog("is_prime(17):", is_prime(17), " is_prime(18):", is_prime(18)):
    iglog("clamp(15,0,10):", clamp(15, 0, 10)):
    iglog("sign(-5):", sign(-5)):
    iglog("abs(-8):", abs(-8), " min(3,9):", min(3, 9), " max(3,9):", max(3, 9)):
    iglog("ord('A'):", ord("A"), " chr(66):", chr(66)):

    // ===== random (seeded, so output is reproducible) =====
    iglog("-- random (seeded) --"):
    rand_seed(42):
    iglog("rand_int(1,100):", rand_int(1, 100)):
    iglog("rand_bool:", rand_bool()):
    iglog("rand_float_pct:", rand_float_pct()):

    // ===== file I/O =====
    iglog("-- file I/O --"):
    let text io_path = "d:/Ignid/demos/demo_io.txt":
    writefile(io_path, "line one\nline two\nline three"):
    let text contents = readfile(io_path):
    iglog("readfile ->", contents):
    let list ls = read_lines(io_path):
    iglog("read_lines count:", len(ls), "first:", ls{0}):
    write_lines(ls, io_path):
    iglog("write_lines re-wrote", len(ls), "lines"):

    // ===== print / println (vs iglog) =====
    iglog("-- print/println --"):
    print("no newline, "): println("then a newline"):

    // ===== system (run a shell command) =====
    iglog("-- system --"):
    let int rc = system("cmd.exe /c exit 0"):
    iglog("system exit code:", rc):

    iglog("== demo complete =="):
]
