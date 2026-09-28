// test_enum.ig — test enum types
enum Color [ Red: Green: Blue: ]
enum Dir [ North: South: East: West: ]

fn color_name(Color c) -> text [
    when c == Color.Red   [ give "red": ]
    when c == Color.Green [ give "green": ]
    give "blue":
]

fn opposite(Dir d) -> Dir [
    when d == Dir.North [ give Dir.South: ]
    when d == Dir.South [ give Dir.North: ]
    when d == Dir.East  [ give Dir.West: ]
    give Dir.East:
]

start [
    let Color c = Color.Red:
    iglog("c =", color_name(c)):

    iglog("Red =", Color.Red):
    iglog("Green =", Color.Green):
    iglog("Blue =", Color.Blue):

    let Color x = Color.Green:
    when x == Color.Green [ iglog("x is green"): ]

    iglog("North =", Dir.North):
    iglog("West =", Dir.West):

    let Dir d = Dir.East:
    iglog("opposite East =", opposite(d)):

    let int sum = Color.Red + Color.Blue:
    iglog("Red + Blue =", sum):
]
