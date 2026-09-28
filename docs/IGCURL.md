# igcurl

A tiny curl-like HTTP client and downloader (`igcurl.ig`), built directly on the
raw TCP socket builtins (`sock_connect` / `sock_send` / `sock_recv_all`). Plain
HTTP only — the runtime has no TLS, so URLs must be `http://`, not `https://`.

```
use "d:/Ignid/igcurl.ig":                       // std.ig comes with it

start [
    let text html = http_get("http://example.com/"):
    iglog(html):

    download("http://example.com/index.html"):    // -> ./library/index.html
    download_as("http://httpbin.org/get", "info.json"):
]
```

See `demos/demoget.ig` for a fuller example, and run it with `ignid demoget.ig`
(no args for a canned tour, or pass it URLs to fetch into `./library`).

## Important limitations, on purpose

- **Plain HTTP only.** No TLS/SSL. `https://` URLs are rejected with a message and
  an empty result. Implementing TLS in the assembly runtime is out of scope.
- **Text responses only.** Bodies are handled as NUL-terminated text, so
  HTML / JSON / CSS / JS / XML / SVG / plain text all download intact, but a
  binary file (image, zip, PDF, …) is observed **truncated at its first NUL
  byte**. This follows from Ignid strings being C strings — it is not specific to
  this library.
- **Single connection at a time.** Every request opens a socket, sends
  `Connection: close`, reads until the server closes, and closes. No connection
  pooling, no keep-alive, no pipelining.
- **No request timeout.** A server that accepts the connection but never responds
  and never closes will hang `sock_recv_all()`. Fine for well-behaved servers.
- **No compression.** The client never sends `Accept-Encoding`, so servers reply
  uncompressed. A server that ignores that and gzips anyway yields an
  unreadable body.
- Cookies, auth, and multipart uploads are not built in — add headers yourself
  via `http_send()`.

## URL parsing

```
rec Url [ text scheme: text host: int port: text path: ]

fn url_parse(text raw) -> Url
```

`url_parse("http://host:8080/a/b?q=1")` →
`Url("http", "host", 8080, "/a/b?q=1")`. Port defaults to 80 for `http`
(443 for a `https` URL, though the client won't fetch it). A missing path
becomes `"/"`.

## Fetching

| Function | Returns |
|---|---|
| `http_get(url)` | response body as text; follows up to 8 redirects; de-chunks a `Transfer-Encoding: chunked` body; `""` on failure |
| `fetch(url)` | alias for `http_get` |
| `http_get_ex(url, max_redirects)` | same, with an explicit redirect budget |
| `http_get_status(url)` | numeric status code of a single `GET` (no redirect following), `0` on failure |
| `http_send(url, method, extra_headers, body)` | the **entire** raw response (status line + headers + body). `extra_headers`, if non-empty, must be complete `Name: value\r\n` lines. `""` on connection failure or an `https://` URL |

Redirects: `http_get` follows `301` / `302` / `303` / `307` / `308`, resolving a
relative `Location` against the current URL. `304` is treated as a normal
response, not a redirect.

## Response helpers

| Function | Returns |
|---|---|
| `http_status_of(resp)` | status code from a raw response's status line |
| `http_header(head, name)` | a header value (case-insensitive name), `""` if absent |

`http_send()` returns the raw response; split it yourself if you need the head:
find `"\r\n\r\n"`, everything before is the header block for `http_header()`,
everything after is the body.

## Downloading

Downloads go into a `library/` folder in the process's current directory, created
on first use.

| Function | Effect |
|---|---|
| `download(url)` | fetch `url`, save to `library/<last-path-segment>` (`index.html` if the URL has no filename). Returns bytes written, `0` on failure |
| `download_as(url, filename)` | fetch `url`, save to `library/<filename>` |
| `url_filename(url)` | the filename `download()` would choose |

The folder name is the `IGCURL_DIR` global (`"library"`) — rebind it before your
first download call to save elsewhere.
