// ignidweb.ig — a tiny Flask-like HTTP server library for Ignid.
// Built on raw TCP socket builtins (sock_listen/sock_accept/sock_recv/sock_send/sock_close),
// which wrap Winsock directly in codegen.ig's runtime. Plain HTTP only (no WebSocket),
// single-threaded (the runtime's heap allocator has no locking, so real OS threads would
// race on it — see demos/demoweb.ig for the request loop shape, including keep-alive).
use "d:/Ignid/std.ig":

fn web_listen(int port) -> int [ give sock_listen(port): ]
fn web_accept(int listener) -> int [ give sock_accept(listener): ]

// ---- request line parsing ----

fn http_first_line(text req) -> text [
    let int i = find(req, "\r"):
    when i < 0 [ i = find(req, "\n"): ]
    when i < 0 [ give req: ]
    give sub(req, 0, i):
]

fn http_method(text req) -> text [
    let list parts = split(http_first_line(req), " "):
    when len(parts) < 1 [ give "": ]
    give parts{0}:
]

// path only, query string (if any) stripped off after '?'
fn http_path(text req) -> text [
    let list parts = split(http_first_line(req), " "):
    when len(parts) < 2 [ give "/": ]
    let text p = parts{1}:
    let int q = find(p, "?"):
    when q >= 0 [ give sub(p, 0, q): ]
    give p:
]

// raw query string (after '?'), or "" if none
fn http_query(text req) -> text [
    let list parts = split(http_first_line(req), " "):
    when len(parts) < 2 [ give "": ]
    let text p = parts{1}:
    let int q = find(p, "?"):
    when q < 0 [ give "": ]
    give sub(p, q + 1, len(p)):
]

// "/users/42/edit" -> ["users","42","edit"]  (for :param-style routing)
fn path_segments(text path) -> list [
    let list raw = split(path, "/"):
    let list result = {}:
    loop seg in raw [
        when len(seg) > 0 [ push(result, seg): ]
    ]
    give result:
]

// ---- percent-decoding (for query strings and form bodies) ----

fn hex_digit_val(text c) -> int [
    let int cc = ord(c):
    when cc >= ord("0") and cc <= ord("9") [ give cc - ord("0"): ]
    when cc >= ord("A") and cc <= ord("F") [ give cc - ord("A") + 10: ]
    when cc >= ord("a") and cc <= ord("f") [ give cc - ord("a") + 10: ]
    give 0:
]

fn url_decode(text s) -> text [
    let text result = "": let int i = 0: let int n = len(s):
    loop while i < n [
        let text c = s{i}:
        when c == "+" [ result = result + " ": i = i + 1: skip: ]
        when c == "%" and i + 2 < n [
            let int v = hex_digit_val(s{i+1}) * 16 + hex_digit_val(s{i+2}):
            result = result + chr(v):
            i = i + 3: skip:
        ]
        result = result + c:
        i = i + 1:
    ]
    give result:
]

// ---- query string / form-body parsing -> map<text,text> ----

fn parse_kv_pairs(text raw) -> map [
    let map m = map_new():
    when len(raw) == 0 [ give m: ]
    let list pairs = split(raw, "&"):
    loop kv in pairs [
        let int eq = find(kv, "="):
        when eq < 0 [
            when len(kv) > 0 [ map_set(m, url_decode(kv), ""): ]
            skip:
        ]
        let text k = url_decode(sub(kv, 0, eq)):
        let text v = url_decode(sub(kv, eq + 1, len(kv))):
        map_set(m, k, v):
    ]
    give m:
]

fn query_params(text req) -> map [ give parse_kv_pairs(http_query(req)): ]

// application/x-www-form-urlencoded bodies parse the same way as query strings
fn form_params(text req) -> map [ give parse_kv_pairs(http_body(req)): ]

// ---- request headers -> map<text,text> (keys lowercased) ----

fn http_headers(text req) -> map [
    let map m = map_new():
    let list lines = split(req, "\r\n"):
    let int i = 1:
    loop while i < len(lines) [
        let text ln = lines{i}:
        when len(ln) == 0 [ stop: ]
        let int c = find(ln, ":"):
        when c > 0 [
            let text k = lower(trim(sub(ln, 0, c))):
            let text v = trim(sub(ln, c + 1, len(ln))):
            map_set(m, k, v):
        ]
        i = i + 1:
    ]
    give m:
]

// ---- request body (everything after the blank-line header terminator) ----

fn http_body(text req) -> text [
    let int i = find(req, "\r\n\r\n"):
    when i < 0 [ give "": ]
    give sub(req, i + 4, len(req)):
]

// ---- keep-alive negotiation ----

fn should_keep_alive(text req) -> int [
    let map h = http_headers(req):
    when map_has(h, "connection") == 1 [
        let text c = lower(map_get_text(h, "connection")):
        when c == "close" [ give 0: ]
        when c == "keep-alive" [ give 1: ]
    ]
    when find(http_first_line(req), "HTTP/1.1") >= 0 [ give 1: ]
    give 0:
]

// ---- response building ----
// keep_alive: 1 sends "Connection: keep-alive" and leaves the socket open for you to
// read another request on it; 0 sends "Connection: close". Either way, ignidweb never
// closes the socket itself — the caller's loop owns that (see demos/demoweb.ig).

fn http_respond(int conn, int status, text status_text, text content_type, text body, int keep_alive) -> int [
    let text conn_hdr = "close":
    when keep_alive == 1 [ conn_hdr = "keep-alive": ]
    let text resp = "HTTP/1.1 " + totext(status) + " " + status_text + "\r\n" +
                     "Content-Type: " + content_type + "\r\n" +
                     "Content-Length: " + totext(len(body)) + "\r\n" +
                     "Connection: " + conn_hdr + "\r\n\r\n" + body:
    sock_send(conn, resp):
    give 0:
]

fn http_ok_html(int conn, text body, int keep_alive) -> int [
    give http_respond(conn, 200, "OK", "text/html; charset=utf-8", body, keep_alive):
]

fn http_ok_text(int conn, text body, int keep_alive) -> int [
    give http_respond(conn, 200, "OK", "text/plain; charset=utf-8", body, keep_alive):
]

fn http_ok_json(int conn, text body, int keep_alive) -> int [
    give http_respond(conn, 200, "OK", "application/json", body, keep_alive):
]

fn http_not_found(int conn, int keep_alive) -> int [
    give http_respond(conn, 404, "Not Found", "text/plain", "404 Not Found", keep_alive):
]

// ---- static file serving ----

fn content_type_for(text path) -> text [
    when ends_with(path, ".html") [ give "text/html; charset=utf-8": ]
    or ends_with(path, ".css")  [ give "text/css": ]
    or ends_with(path, ".js")   [ give "application/javascript": ]
    or ends_with(path, ".json") [ give "application/json": ]
    or ends_with(path, ".png")  [ give "image/png": ]
    or ends_with(path, ".jpg")  [ give "image/jpeg": ]
    or ends_with(path, ".jpeg") [ give "image/jpeg": ]
    or ends_with(path, ".svg")  [ give "image/svg+xml": ]
    or ends_with(path, ".txt")  [ give "text/plain": ]
    give "application/octet-stream":
]

fn http_serve_file(int conn, text fs_path, int keep_alive) -> int [
    let text content = "": let int ok = 1:
    try [
        content = readfile(fs_path):
    ] catch [
        ok = 0:
    ]
    when ok == 0 [ give http_not_found(conn, keep_alive): ]
    give http_respond(conn, 200, "OK", content_type_for(fs_path), content, keep_alive):
]

// ---- flat JSON (string keys, int/text values only — no nested objects/arrays) ----

fn json_escape(text s) -> text [
    let text r = "": let int i = 0: let int n = len(s):
    loop while i < n [
        let text c = s{i}:
        when c == "\"" [ r = r + "\\\"": ]
        or c == "\\" [ r = r + "\\\\": ]
        or c == "\n" [ r = r + "\\n": ]
        or c == "\r" [ r = r + "\\r": ]
        else [ r = r + c: ]
        i = i + 1:
    ]
    give r:
]

fn json_str(text key, text val) -> text [
    give "\"" + json_escape(key) + "\":\"" + json_escape(val) + "\"":
]

fn json_num(text key, int val) -> text [
    give "\"" + json_escape(key) + "\":" + totext(val):
]

fn json_object(list fields) -> text [ give "{" + join(fields, ",") + "}": ]

// parses a flat {"k":"v","k2":123} object into map<text,text> (numbers come back as
// their text form — toint()/tofloat() them yourself if needed)
fn json_decode(text s) -> map [
    let map m = map_new():
    let int i = 0: let int n = len(s):
    loop while i < n and s{i} != "{" [ i = i + 1: ]
    i = i + 1:
    loop while i < n [
        loop while i < n and (s{i} == " " or s{i} == "," or s{i} == "\n" or s{i} == "\r" or s{i} == "\t") [ i = i + 1: ]
        when i >= n or s{i} == "}" [ stop: ]
        when s{i} != "\"" [ stop: ]
        i = i + 1:
        let int ks = i:
        loop while i < n and s{i} != "\"" [ i = i + 1: ]
        let text key = sub(s, ks, i):
        i = i + 1:
        loop while i < n and s{i} != ":" [ i = i + 1: ]
        i = i + 1:
        loop while i < n and s{i} == " " [ i = i + 1: ]
        let text val = "":
        when i < n and s{i} == "\"" [
            i = i + 1:
            let int vs = i:
            loop while i < n and s{i} != "\"" [ i = i + 1: ]
            val = sub(s, vs, i):
            i = i + 1:
        ]
        else [
            let int vs = i:
            loop while i < n and s{i} != "," and s{i} != "}" [ i = i + 1: ]
            val = trim(sub(s, vs, i)):
        ]
        map_set(m, key, val):
    ]
    give m:
]
