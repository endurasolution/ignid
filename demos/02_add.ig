// 02_add.ig — basics: numbers, arithmetic, user input
start [
    let int a = toint(ask("First number: ")):
    let int b = toint(ask("Second number: ")):
    let int sum = a + b:
    iglog(a, "+", b, "=", sum):
]
