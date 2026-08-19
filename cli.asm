; cli/cli.asm - asx CLI:
;   asx init [name]   scaffold a project: clone the asx framework
;                      (compiled-in url) + boilerplate
;   asx build         compile the app
;   asx dev           compile and run
;   asx               show help

%include "syscalls.inc"

extern cli_strcmp
extern asx_init
extern cli_run_build
extern cli_run_dev

section .data
    default_pkg db "asx", 0
    default_url db "https://github.com/weslleymirandadev/asx.git", 0
    cmd_init    db "init", 0
    cmd_build   db "build", 0
    cmd_dev     db "dev", 0
    help_text   db "asx - assembly web framework CLI", 10
                db "usage:", 10
                db "  asx init [name]   create a project: clones the asx framework", 10
                db "                     into name/ and scaffolds", 10
                db "                     src/main.asm, src/app/api/hello/route.s, Makefile", 10
                db "  asx build         compile the app", 10
                db "  asx dev           compile and run", 10
                db "  asx               show this help", 10, 0
    help_len equ $ - help_text - 1

section .text
global _start
_start:
    ; Linux entry: argc at [rsp], argv at [rsp+8] (not rdi/rsi!)
    mov r13, [rsp]          ; argc
    lea r12, [rsp + 8]      ; argv
    cmp r13, 1
    jle .help
    mov rdi, [r12 + 8]      ; argv[1]
    lea rsi, [cmd_init]
    call cli_strcmp
    test rax, rax
    jz .do_init
    mov rdi, [r12 + 8]
    lea rsi, [cmd_build]
    call cli_strcmp
    test rax, rax
    jz .do_build
    mov rdi, [r12 + 8]
    lea rsi, [cmd_dev]
    call cli_strcmp
    test rax, rax
    jz .do_dev
    jmp .help
.do_init:
    ; name = argv[2] or "asx"; url = compiled-in default
    cmp r13, 2
    jg .init_name
    lea r14, [default_pkg]
    jmp .init_go
.init_name:
    mov r14, [r12 + 16]
.init_go:
    mov rdi, r14
    lea rsi, [default_url]
    call asx_init
    jmp .exit0
.do_build:
    call cli_run_build
    mov rdi, rax
    jmp .exit
.do_dev:
    call cli_run_dev        ; execs the server on success
    mov rdi, rax
    jmp .exit
.help:
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [help_text]
    mov rdx, help_len
    syscall
.exit0:
    xor rdi, rdi
.exit:
    mov rax, SYS_exit
    syscall
