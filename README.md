# wolfram-lang
Wolfram

CLI:
wfm --version
wfm --help
wfm --docs
wfm parse path/to/file.w
wfm build path/to/wolcon.yml
wfm debug path/to/file.w # просто ищет ошибки, не выполняет
wfm run path/to/file.w

ERROR. SYNTAX ERROR:
    ├> Missing semicolon (Token: tkSemi)
    │
    ├> "F:/path/to/file.pd":1:21
    │
    └>  3 | sendln("Hello World")
                                 ^
                                Here

ERROR. SYNTAX ERROR:
    ├> Missing right parenthesis (Token: tkRParen)
    │
    ├> "F:/path/to/file.pd":3:10
    │
    └>  3 | if (x == 4 {
                      ^
                     Here
