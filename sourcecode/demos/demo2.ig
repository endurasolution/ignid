// demo2.ig — reusable functions & records, meant to be pulled in via `use "demo2.ig":`
// (no `use std.ig` here on purpose — demo.ig already uses it directly, and reusing
// the same file from two places in one program can duplicate symbols)

fn appname() -> text [ give "Ignid Demo App": ]
fn appversion() -> text [ give "1.0.0": ]

// class-style "object" — see demo.ig for how it's used
rec Account [ text owner: int balance: ]

fn new_account(text owner, int opening) -> Account [
    give Account(owner, opening):
]

fn deposit(Account a, int amount) -> int [
    a.balance = a.balance + amount:
    give a.balance:
]

fn describe(Account a) -> text [
    give a.owner + ": $" + totext(a.balance):
]
