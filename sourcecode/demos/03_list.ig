// 03_list.ig — basics: lists, push, join, sort
use "d:/Ignid/std.ig":

start [
    let list fruits = {}:
    push(fruits, "apple"):
    push(fruits, "banana"):
    push(fruits, "cherry"):

    iglog("List has", len(fruits), "items:", join(fruits, ", ")):

    let list sorted = sort_str(fruits):
    iglog("Sorted:", join(sorted, ", ")):
]
