// test_rec.ig — test rec (record) types

rec Point [ int x: int y: ]

rec Color [ int r: int g: int b: ]

fn make_point(int x, int y) -> Point [
    give Point(x, y):
]

fn brightness(Color c) -> int [
    give c.r + c.g + c.b:
]

start [
    let Point p = Point(3, 4):
    iglog("x =", p.x):
    iglog("y =", p.y):

    p.x = 10:
    iglog("after set x =", p.x):

    let Point q = make_point(7, 8):
    iglog("q.x =", q.x, "q.y =", q.y):

    let Color red = Color(255, 0, 0):
    iglog("brightness =", brightness(red)):

    let int sum = p.x + q.y:
    iglog("p.x + q.y =", sum):
]
