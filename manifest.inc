; cli/manifest.inc - framework payload embedded in the asmx CLI.
; Each pkg_file entry: 1st arg = path relative to the package dir
; (extraction target), 2nd arg = source path for incbin (resolved from
; the NASM working directory = repo root). Entries land in the
; pkg_manifest section (24 bytes each: dq data, len, path) and GNU ld
; defines __start_pkg_manifest/__stop_pkg_manifest over it.

%macro pkg_file 2
    section pkg_data
    %%data: incbin %2
    %%len equ $ - %%data
    section pkg_paths
    %%path: db %1, 0
    section pkg_manifest
    dq %%data, %%len, %%path
%endmacro

pkg_file "asmx.inc",            "asmx/asmx.inc"
pkg_file "asmx/core.asm",       "asmx/asmx/core.asm"
pkg_file "asmx/helpers.asm",    "asmx/asmx/helpers.asm"
pkg_file "asmx/router.asm",     "asmx/asmx/router.asm"
pkg_file "asmx/send.asm",       "asmx/asmx/send.asm"
pkg_file "asmx/state.asm",      "asmx/asmx/state.asm"
pkg_file "common/common.inc",   "asmx/common/common.inc"
pkg_file "common/errors.asm",   "asmx/common/errors.asm"
pkg_file "common/macros.inc",   "asmx/common/macros.inc"
pkg_file "common/strings.asm",  "asmx/common/strings.asm"
pkg_file "common/strings.inc",  "asmx/common/strings.inc"
pkg_file "common/syscalls.inc", "asmx/common/syscalls.inc"
pkg_file "net/net.asm",         "asmx/net/net.asm"
pkg_file "net/net.inc",         "asmx/net/net.inc"
pkg_file "http/getters.asm",    "asmx/http/getters.asm"
pkg_file "http/handler.asm",    "asmx/http/handler.asm"
pkg_file "http/header_parse.asm", "asmx/http/header_parse.asm"
pkg_file "http/http.inc",       "asmx/http/http.inc"
pkg_file "http/line_scanner.asm", "asmx/http/line_scanner.asm"
pkg_file "http/method_check.asm", "asmx/http/method_check.asm"
pkg_file "http/request_line.asm", "asmx/http/request_line.asm"
pkg_file "http/response.asm",   "asmx/http/response.asm"
pkg_file "http/state.asm",      "asmx/http/state.asm"
