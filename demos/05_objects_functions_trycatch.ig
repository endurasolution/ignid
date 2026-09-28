// 05_objects_functions_trycatch.ig
// Records ("object-wise" data + calling), passing data between functions, and try/catch.
use "d:/Ignid/std.ig":

// -- records ("objects") --
rec Point [ int x: int y: ]

fn make_point(int x, int y) -> Point [
    give Point(x, y):
]

fn distance_sq(Point a, Point b) -> int [
    let int dx = a.x - b.x:
    let int dy = a.y - b.y:
    give dx * dx + dy * dy:
]

// -- passing data from one function to another --
fn square(int n) -> int [ give n * n: ]
fn sum_of_squares(int a, int b) -> int [
    give square(a) + square(b):   // result of square() feeds straight into +
]

start [
    iglog("== records ('objects') =="):
    let Point p1 = make_point(1, 2):
    let Point p2 = Point(4, 6):
    iglog("p1 =", p1.x, p1.y):
    iglog("p2 =", p2.x, p2.y):
    p1.x = 10:
    iglog("p1 after mutation:", p1.x, p1.y):
    iglog("distance_sq(p1, p2) =", distance_sq(p1, p2)):

    iglog("== passing data between functions =="):
    iglog("sum_of_squares(3, 4) =", sum_of_squares(3, 4)):

    iglog("== try / catch =="):
    try [
        let int bad = toint("not-a-number"):
        iglog("unreachable:", bad):
    ] catch [
        iglog("caught error:", lasterror()):
    ]
    iglog("execution continues after catch"):

    let list nums = {}:
    push(nums, 10): push(nums, 20):
    try [
        iglog("nums{5} =", nums{5}):   // out of bounds -> caught, not a crash
    ] catch [
        iglog("caught error:", lasterror()):
    ]
    iglog("done"):
]
