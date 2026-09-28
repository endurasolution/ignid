// 07_map_float.ig — map and float, the two newest additions to the language.
use "d:/Ignid/std.ig":

start [
    iglog("== float =="):
    let float pi = 3.14159265:
    let float two = 2.0:
    iglog("pi =", pi):                      // trimmed to 6 decimals: 3.141593
    iglog("pi * 2 =", pi * two):
    let int n = 3:
    iglog("mixed int+float: n + pi =", n + pi):
    iglog("comparisons: pi > 3.0 =", pi > 3.0):

    iglog("== map literal =="):
    let map ages = {"alice" -> 30, "bob" -> 25}:
    iglog("alice is", map_get_int(ages, "alice")):
    map_set(ages, "carol", 40):
    iglog("map has", len(ages), "entries:", join(map_keys(ages), ", ")):

    iglog("== map built with map_new =="):
    let map scores = map_new():
    map_set(scores, "alice", 97.5):
    map_set(scores, "bob", 88.25):
    iglog("alice scored", map_get_float(scores, "alice")):

    iglog("== map + try/catch on a missing key =="):
    try [
        let int missing = map_get_int(ages, "dave"):
        iglog("unreachable:", missing):
    ] catch [
        iglog("caught:", lasterror()):
    ]

    iglog("== string interpolation with a map value =="):
    let float bobscore = map_get_float(scores, "bob"):
    iglog("bob's score is ${bobscore}, half of it is ${bobscore / 2.0}"):
]
