# Demos

Runnable example programs, roughly ordered from simplest to most advanced. Compile
and run any of them with `ignid <file>.ig` from this directory.

| File | Covers |
|---|---|
| `01_hello.ig` | variables, text, input |
| `02_add.ig` | arithmetic, input |
| `03_list.ig` | lists, `push`, `join`, sorting |
| `04_forloop.ig` | if/elif/else, for/while/repeat loops |
| `05_objects_functions_trycatch.ig` | records, function-to-function data passing, try/catch |
| `06_class_style.ig` | records used as "classes" (free functions as methods) |
| `07_map_float.ig` | `map` (literal + builder syntax), `float`, string interpolation |
| `demo.ig` (+ `demo2.ig`) | a fuller tour of the whole language and standard library; `demo2.ig` shows cross-file `use` |
| `demoweb.ig` | a small web app using `ignidweb` — routing, query params, POST bodies, path segments, static files, keep-alive, flat JSON |
| `demoget.ig` | a curl-like downloader using `igcurl` — `http_get`, redirects, status codes, and saving files into a `library/` folder |

`static/` holds a static asset (`style.css`) served by `demoweb.ig` to demonstrate
`http_serve_file()`.

Run `demoget.ig` with no arguments for a canned tour, or pass it one or more
`http://` URLs to fetch into `./library`:  `ignid demoget.ig http://example.com/`.

See [../docs/LANGUAGE.md](../docs/LANGUAGE.md) for the full language reference and
[../docs/STDLIB.md](../docs/STDLIB.md) for every built-in/standard-library function
used across these demos.
