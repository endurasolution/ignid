// test_stage9.ig — tests string interpolation (${...}), modules, match
use "d:/Ignid/math.ig":

enum Season [ Spring: Summer: Autumn: Winter: ]

fn season_name(Season s) -> text [
    match s [
        Season.Spring [ give "spring": ]
        Season.Summer [ give "summer": ]
        Season.Autumn [ give "autumn": ]
        else          [ give "winter": ]
    ]
]

start [
    // string interpolation with ${...}
    let int x = 7:
    let int y = 3:
    iglog("x = ${x}, y = ${y}"):
    let int sum = x + y:
    iglog("x + y = ${sum}"):

    // modules: functions from math.ig
    let int sq = square(x):
    iglog("square(${x}) = ${sq}"):
    let int c = clamp(15, 0, 10):
    iglog("clamp(15,0,10) = ${c}"):
    let int sg = sign(-5):
    iglog("sign(-5) = ${sg}"):

    // match
    let Season s = Season.Autumn:
    let text sn = season_name(s):
    iglog("season = ${sn}"):
    match s [
        Season.Spring [ iglog("it is spring"): ]
        Season.Autumn [ iglog("it is autumn"): ]
        else          [ iglog("other season"): ]
    ]
]
