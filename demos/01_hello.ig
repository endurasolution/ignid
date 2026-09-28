// 01_hello.ig — basics: variables, text concatenation, user input
use "d:/Ignid/std.ig":

start [
    let text name = trim(ask("What is your name? ")):
    iglog("Hello, " + name + "! Welcome to Ignid."):
]
