// demoget.ig — a curl-like downloader built on igcurl.ig.
// Run with:  ignid demoget.ig  [url ...]
//
// With no arguments it fetches a couple of well-known plain-HTTP pages into a
// ./library folder. With arguments, each is treated as an http:// URL to fetch
// and save into ./library, named after the URL's last path segment.
//
// Plain HTTP only — igcurl has no TLS, so https:// URLs are rejected. Text
// responses (HTML/JSON/CSS/JS/XML/plain text) download intact; binary files are
// truncated at their first NUL byte (Ignid strings are NUL-terminated).
use "d:/Ignid/igcurl.ig":

fn show_head(text label, text body) -> int [
    let int n = len(body):
    let int cut = 200:
    when n < cut [ cut = n: ]
    iglog("--", label, "(" + totext(n) + " bytes) --"):
    iglog(sub(body, 0, cut)):
    iglog(""):
    give 0:
]

start [
    when argc() > 0 [
        let int i = 0:
        loop while i < argc() [
            download(argv(i)):
            i = i + 1:
        ]
        quit(0):
    ]

    iglog("== igcurl demo =="):
    iglog(""):

    // 1. fetch a page and look at it in memory
    let text page = http_get("http://example.com/"):
    show_head("http://example.com/", page):

    // 2. a JSON API (httpbin echoes request info as JSON)
    let text info = http_get("http://httpbin.org/get"):
    show_head("http://httpbin.org/get", info):

    // 3. status code without downloading a body we care about
    iglog("status of /status/404:", totext(http_get_status("http://httpbin.org/status/404"))):
    iglog(""):

    // 4. save files into ./library
    iglog("== downloading into ./library =="):
    download("http://example.com/index.html"):
    download_as("http://httpbin.org/get", "httpbin-get.json"):
    download_as("http://httpbin.org/html", "httpbin.html"):

    iglog(""):
    iglog("done — see the ./library folder"):
]
