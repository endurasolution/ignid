# ignidweb

A small Flask-like HTTP library (`ignidweb.ig`), built directly on raw TCP socket
builtins. Plain HTTP only — no WebSocket, no HTTPS.

```
use "d:/Ignid/ignidweb.ig":

fn handle_home() -> text [ give "<h1>hi</h1>": ]

start [
    let int listener = web_listen(8080):
    loop while true [
        let int conn = web_accept(listener):
        let text req = sock_recv(conn):
        let text path = http_path(req):
        when path == "/" [ http_ok_html(conn, handle_home(), 0): ]
        else              [ http_not_found(conn, 0): ]
        sock_close(conn):
    ]
]
```

See `demos/demoweb.ig` for a fuller example covering everything below, and run it
with `ignid demoweb.ig` — it listens on `http://localhost:8080/`.

## Important limitations, on purpose

- **Single-threaded.** The runtime's memory allocator has no locking, so real OS
  threads handling requests concurrently would corrupt the heap. One request is
  handled at a time (or, with keep-alive, one *connection* at a time, serially).
  Fine for local tools and demos; not something to expose to real concurrent load.
- **Flat JSON only.** `map` only stores flat `text`/`int`/`float` values, so there's
  no nested-object/array JSON support — see [Flat JSON](#flat-json) below.
- No HTTPS/TLS, no chunked transfer encoding, no cookies/sessions, no request
  timeouts (a slow client can stall the server), no request-size handling beyond
  a single ~4KB `sock_recv()` read.
- No path sanitization in `http_serve_file()` — don't route a URL segment straight
  into a filesystem path without validating it yourself, or you have a directory
  traversal vulnerability.

## Routing

There's no `@app.route()` decorator — Ignid has no first-class functions, so
there's nothing to register a handler *as*. Routing is just `when`/`or`/`else` on
the path, inside your own accept loop:

```
when path == "/" [ ... ]
or path == "/about" [ ... ]
else [ http_not_found(conn, alive): ]
```

For `/users/:id`-style routes, use `path_segments(path)` and check/index manually:

```
let list segs = path_segments(path):     // "/users/42" -> ["users", "42"]
when len(segs) == 2 and segs{0} == "users" [
    let text id = segs{1}:
    ...
]
```

## Request parsing

| Function | Returns |
|---|---|
| `http_method(req)` | `"GET"`, `"POST"`, etc. |
| `http_path(req)` | path only, query string stripped |
| `http_query(req)` | raw query string (after `?`), or `""` |
| `query_params(req)` | `map` of parsed `?key=value&...` pairs, percent-decoded |
| `http_headers(req)` | `map` of request headers, keys lowercased |
| `http_body(req)` | everything after the header/body blank-line separator |
| `form_params(req)` | `map` — parses `http_body(req)` the same way as a query string, for `application/x-www-form-urlencoded` POST bodies |
| `path_segments(path)` | `list` of non-empty `/`-separated path parts |

## Responding

```
http_respond(conn, status, status_text, content_type, body, keep_alive)
http_ok_html(conn, body, keep_alive)      // 200, text/html
http_ok_text(conn, body, keep_alive)       // 200, text/plain
http_ok_json(conn, body, keep_alive)        // 200, application/json
http_not_found(conn, keep_alive)             // 404
```

`keep_alive` is `0` or `1` — see below. **None of these close the socket.** Your
accept loop owns `sock_close()`, called once after it's done reading requests off
a connection (see the keep-alive pattern below) — this is deliberate, not an
oversight, so the same connection can be reused for multiple requests.

## Keep-alive

```
fn should_keep_alive(text req) -> int
```

Checks the request's `Connection` header, falling back to the HTTP/1.1-defaults-
to-keep-alive / HTTP/1.0-defaults-to-close rule. The idiomatic loop shape (see
`demos/demoweb.ig` in full):

```
loop while true [
    let int conn = web_accept(listener):
    let int alive = 1:
    let int reqcount = 0:
    loop while alive == 1 and reqcount < 100 [
        let text req = sock_recv(conn):
        when len(req) == 0 [ stop: ]          // client closed
        reqcount = reqcount + 1:
        alive = should_keep_alive(req):
        // ... route and respond, passing `alive` as keep_alive ...
    ]
    sock_close(conn):                            // exactly once, after the inner loop
]
```

## Static files

```
http_serve_file(conn, fs_path, keep_alive)
```

Reads `fs_path` from disk, guesses `Content-Type` from the extension
(`.html`/`.css`/`.js`/`.json`/`.png`/`.jpg`/`.svg`/`.txt`, else
`application/octet-stream`), and responds 404 cleanly if the file doesn't exist.
**Does not sanitize `fs_path`** — if you build it from user input (e.g. a URL
path), validate/whitelist it yourself first.

## Flat JSON

`map` only holds flat `text`/`int`/`float` values (see
[LANGUAGE.md](LANGUAGE.md#maps)), so there's no generic map-to-JSON serializer.
Instead, build JSON explicitly, one field at a time:

```
let list fields = {}:
push(fields, json_str("name", "Alice")):
push(fields, json_num("age", 30)):
let text body = json_object(fields):          // {"name":"Alice","age":30}
http_ok_json(conn, body, alive):
```

| Function | Signature |
|---|---|
| `json_str(key, val)` | `text, text -> text` — one `"k":"v"` field |
| `json_num(key, val)` | `text, int -> text` — one `"k":v` field |
| `json_object(fields)` | `list -> text` — joins fields with commas, wraps in `{}` |
| `json_escape(s)` | `text -> text` — escapes `"`, `\`, newlines |
| `json_decode(s)` | `text -> map` — parses a flat `{"k":"v",...}` object; all values come back as text, `toint()`/`tofloat()` them yourself |

No nested objects or arrays, either direction.
