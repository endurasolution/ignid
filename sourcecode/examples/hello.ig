// hello.ig — first ever Ignid program

fix appname = "Ignid":

fn fib(int n) -> int [
    when n < 2 [ give n: ]
    give fib(n - 1) + fib(n - 2):
]

start [
    iglog("Welcome to {appname}!"):

    let any a = 42:
    a = "any can hold anything":
    iglog(a):

    let var count = 0:        // locks as int
    loop i in 1 to 10 [
        count = count + fib(i):
    ]
    iglog("Sum of fib(1..10): {count}"):

    loop 3 [
        iglog.warn("repeat loop works"):
    ]

    let int x = 7:
    when x > 10 [ iglog("big"): ]
    or x > 5    [ iglog("medium"): ]
    else        [ iglog("small"): ]
]