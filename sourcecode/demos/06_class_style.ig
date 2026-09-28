// 06_class_style.ig — "class"-style usage in Ignid via rec (records) + functions as methods.
// Ignid has no dot-call methods (no obj.method()) — instead you write free functions
// that take the record as their first argument, e.g. deposit(acc, 50) instead of acc.deposit(50).
// Records are reference types (like objects): mutating fields inside a function is
// visible to the caller, exactly like a class instance.
use "d:/Ignid/std.ig":

rec Account [ text owner: int balance: ]

// "constructor"
fn new_account(text owner, int opening) -> Account [
    give Account(owner, opening):
]

// "methods" — take the instance as the first parameter
fn deposit(Account a, int amount) -> int [
    a.balance = a.balance + amount:
    give a.balance:
]

fn withdraw(Account a, int amount) -> int [
    when amount > a.balance [
        iglog("withdraw refused: insufficient funds"):
        give a.balance:
    ]
    a.balance = a.balance - amount:
    give a.balance:
]

fn describe(Account a) -> text [
    give a.owner + ": $" + totext(a.balance):
]

start [
    iglog("== class-style demo (rec + methods) =="):

    let Account acc = new_account("Alice", 100):
    iglog(describe(acc)):

    deposit(acc, 50):
    iglog("after deposit(50):", describe(acc)):

    withdraw(acc, 30):
    iglog("after withdraw(30):", describe(acc)):

    // multiple independent instances
    let Account acc2 = new_account("Bob", 20):
    deposit(acc2, 5):
    iglog(describe(acc2)):

    withdraw(acc2, 1000):   // more than the balance -> refused, unchanged
    iglog("after failed withdraw:", describe(acc2)):

    iglog("acc and acc2 are independent:", describe(acc), "|", describe(acc2)):
]
