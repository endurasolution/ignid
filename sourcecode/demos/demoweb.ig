// demoweb.ig — a fuller Flask-like web app built on ignidweb.ig.
// Run with: ignid demoweb.ig
// Then open http://localhost:8080/ in a browser.
//
// Demonstrates: routing, query params, request headers, POST body / form params,
// path segments (:id-style routing), static file serving, keep-alive, and flat JSON.
use "d:/Ignid/ignidweb.ig":

fn page(text title, text body) -> text [
    give "<!doctype html><html><head><title>" + title +
         "</title><style>body{font-family:sans-serif;max-width:640px;margin:40px auto;padding:0 16px}" +
         "nav a{margin-right:12px}form{margin:16px 0}</style></head><body>" +
         "<nav><a href='/'>Home</a><a href='/about'>About</a><a href='/time'>Time</a>" +
         "<a href='/greet?name=World'>Greet</a><a href='/echo'>Echo (POST)</a>" +
         "<a href='/api/user'>API</a><a href='/users/42'>User 42</a>" +
         "<a href='/static/style.css'>Static CSS</a></nav><hr>" + body + "</body></html>":
]

fn handle_home() -> text [
    give page("Ignid Demo Web", "<h1>Hello from ignidweb!</h1><p>This page was served by a native Ignid executable — no Python, no Node, just a self-hosted compiler and raw Winsock sockets.</p>"):
]

fn handle_about() -> text [
    give page("About", "<h1>About</h1><p>ignidweb is a minimal Flask-like HTTP library for the Ignid language, built directly on <code>sock_listen</code>/<code>sock_accept</code>/<code>sock_recv</code>/<code>sock_send</code> runtime builtins. Single-threaded, keep-alive aware, plain HTTP.</p>"):
]

fn handle_time() -> text [
    give page("Time", "<h1>Server clock()</h1><p>ms since some epoch: " + totext(clock()) + "</p>"):
]

// GET /greet?name=Alice
fn handle_greet(text req) -> text [
    let map q = query_params(req):
    let text who = "World":
    when map_has(q, "name") == 1 [ who = map_get_text(q, "name"): ]
    give page("Greet", "<h1>Hello, " + who + "!</h1><p>Try <code>/greet?name=Alice</code>.</p>"):
]

// GET shows a form; POST echoes the submitted body back
fn handle_echo(text req) -> text [
    when http_method(req) == "POST" [
        let text body = http_body(req):
        give page("Echo", "<h1>You POSTed:</h1><pre>" + body + "</pre><p><a href='/echo'>back</a></p>"):
    ]
    give page("Echo", "<h1>Echo</h1><form method='POST' action='/echo'>" +
        "<input name='message' value='hello'><button type='submit'>POST it</button></form>"):
]

// GET /api/user -> flat JSON via json_object/json_str/json_num
fn handle_api_user() -> text [
    let list fields = {}:
    push(fields, json_str("name", "Alice")):
    push(fields, json_num("age", 30)):
    push(fields, json_str("role", "admin")):
    give json_object(fields):
]

// GET /users/:id  (path-segment routing, no dedicated syntax — just list indexing)
fn handle_user(list segs) -> text [
    let text id = segs{1}:
    give page("User " + id, "<h1>User #" + id + "</h1><p>(looked up via path_segments())</p>"):
]

start [
    let int port = 8080:
    let int listener = web_listen(port):
    iglog("ignidweb listening on http://localhost:" + totext(port)):

    loop while true [
        let int conn = web_accept(listener):
        let int alive = 1:
        let int reqcount = 0:

        loop while alive == 1 and reqcount < 100 [
            let text req = sock_recv(conn):
            when len(req) == 0 [ stop: ]
            reqcount = reqcount + 1:
            alive = should_keep_alive(req):

            let text path = http_path(req):
            let list segs = path_segments(path):
            iglog("request:", http_method(req), path, "keep_alive=", alive):

            when path == "/" [ http_ok_html(conn, handle_home(), alive): ]
            or path == "/about" [ http_ok_html(conn, handle_about(), alive): ]
            or path == "/time" [ http_ok_html(conn, handle_time(), alive): ]
            or path == "/greet" [ http_ok_html(conn, handle_greet(req), alive): ]
            or path == "/echo" [ http_ok_html(conn, handle_echo(req), alive): ]
            or path == "/api/user" [ http_ok_json(conn, handle_api_user(), alive): ]
            or path == "/static/style.css" [ http_serve_file(conn, "d:/Ignid/demos/static/style.css", alive): ]
            or (len(segs) == 2 and segs{0} == "users") [ http_ok_html(conn, handle_user(segs), alive): ]
            else [ http_not_found(conn, alive): ]
        ]
        sock_close(conn):
    ]
]
