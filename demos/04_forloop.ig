// 04_forloop.ig — basics: for loop, repeat loop, while loop
start [
    iglog("-- for loop (0 to 5) --"):
    loop i in 0 to 5 [
        iglog("i =", i):
    ]

    iglog("-- repeat 3 times --"):
    loop 3 [
        iglog("hi"):
    ]

    iglog("-- while loop --"):
    let int n = 5:
    loop while n > 0 [
        iglog("countdown:", n):
        n = n - 1:
    ]
    iglog("liftoff!"):
]
