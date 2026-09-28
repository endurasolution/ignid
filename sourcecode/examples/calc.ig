// calc.ig — Ignid native interactive calculator

start [
    iglog("== Ignid Calculator =="):
    loop while true [
        let text first = ask("First number (q to quit): "):
        when first == "q" [ stop: ]
        let int a = toint(first):
        let int b = toint(ask("Second number: ")):
        let text op = ask("Operation (+ - * / %): "):

        when op == "+" [ iglog("Result:", a + b): ]
        or op == "-"   [ iglog("Result:", a - b): ]
        or op == "*"   [ iglog("Result:", a * b): ]
        or op == "/"   [ iglog("Result:", a / b): ]
        or op == "%"   [ iglog("Result:", a % b): ]
        else           [ iglog.err("unknown operation"): ]
    ]
    iglog("Goodbye!"):
]