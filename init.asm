; cli/init.asm - asmx_init: scaffold a new project in the CWD.
; Extracts the embedded framework into <name>/ and writes the boilerplate
; (src/main.asm, src/app/api/hello/route.s, zero-maintenance Makefile).

%include "syscalls.inc"

extern __start_pkg_manifest
extern __stop_pkg_manifest
extern cli_mkdir_p
extern cli_write_file
extern cli_strlen
extern cli_strcpy

section .bss
    path_buf resb 1024
    dir_buf  resb 1024

section .text

; asmx_init(rdi = package name) -> rax = 0
global asmx_init
asmx_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi            ; pkg name
    mov r13, __start_pkg_manifest
    mov r14, __stop_pkg_manifest

    ; boilerplate dirs
    lea rdi, [dir_src_hello]
    call cli_mkdir_p        ; src/app/api/hello

    ; extract framework files
.entry_loop:
    cmp r13, r14
    jge .entries_done
    ; dest = "<pkg>/<rel>" in path_buf
    lea rdi, [path_buf]
    mov rsi, r12
    call cli_strcpy
    mov rdi, path_buf
    call cli_strlen
    lea rdi, [path_buf + rax]
    mov byte [rdi], '/'
    inc rdi
    mov rsi, [r13 + 16]     ; rel path ptr
    call cli_strcpy
    ; dirname: truncate path_buf at the last '/'
    mov rdi, path_buf
    call cli_strlen
    lea rbx, [path_buf + rax]
.dir_loop:
    cmp rbx, path_buf
    jbe .dir_root
    dec rbx
    cmp byte [rbx], '/'
    je .dir_found
    jmp .dir_loop
.dir_root:
    lea rbx, [path_buf]
.dir_found:
    mov byte [rbx], 0
    mov rdi, dir_buf
    lea rsi, [path_buf]
    call cli_strcpy
    mov rdi, dir_buf
    call cli_mkdir_p
    mov byte [rbx], '/'
    ; write the file
    mov rdi, path_buf
    mov rsi, [r13]          ; data ptr
    mov rdx, [r13 + 8]      ; len
    call cli_write_file
    add r13, 24
    jmp .entry_loop
.entries_done:
    ; boilerplate files
    lea rdi, [path_main]
    lea rsi, [tpl_main]
    mov rdx, tpl_main_len
    call cli_write_file
    lea rdi, [path_route]
    lea rsi, [tpl_route]
    mov rdx, tpl_route_len
    call cli_write_file
    ; Makefile: mount "<mk1><pkg><mk2>" in path_buf
    lea rdi, [path_buf]
    lea rsi, [tpl_mk1]
    call cli_strcpy
    mov rdi, path_buf
    call cli_strlen
    lea rdi, [path_buf + rax]
    mov rsi, r12
    call cli_strcpy
    mov rdi, path_buf
    call cli_strlen
    lea rdi, [path_buf + rax]
    lea rsi, [tpl_mk2]
    call cli_strcpy
    mov rdi, path_buf
    call cli_strlen
    mov rdx, rax
    lea rdi, [path_makefile]
    lea rsi, [path_buf]
    call cli_write_file
    xor rax, rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .data
    dir_src_hello db "src/app/api/hello", 0
    path_main     db "src/main.asm", 0
    path_route    db "src/app/api/hello/route.s", 0
    path_makefile db "Makefile", 0

    tpl_main db "; src/main.asm - asmx app entry", 10
             db '%include "asmx.inc"', 10, 10
             db "section .text", 10
             db "global _start", 10
             db "_start:", 10
             db "    listen 8080", 10
             db "    jmp route_dispatch", 10, 0
    tpl_main_len equ $ - tpl_main - 1

    tpl_route db "; src/app/api/hello/route.s", 10
              db '%include "asmx.inc"', 10, 10
              db "section .data", 10
              db "    hello db '{", 34, "hello", 34, ": ", 34, "world", 34, "}', 0", 10, 10
              db 'route "/api/hello", get_hello, 0', 10, 10
              db "section .GET", 10
              db "get_hello:", 10
              db "    send_json hello", 10
              db "    jmp requests", 10, 0
    tpl_route_len equ $ - tpl_route - 1

    tpl_mk1 db "AS      := nasm", 10
            db "LD      := ld", 10
            db "PKG     := ", 0

    tpl_mk2 db 10
            db "ASFLAGS := -f elf64 -I $(PKG) -I src", 10
            db "BUILD   := build", 10
            db "TARGET  := $(BUILD)/server", 10, 10
            db "# Zero-maintenance: every .asm in the package and every .asm/.s under src/", 10
            db "# is picked up automatically. No Makefile edits for new folders or routes.", 10
            db "PKG_SRCS := $(shell find $(PKG) -name '*.asm')", 10
            db "APP_ASM  := $(shell find src -type f -name '*.asm')", 10
            db "APP_S    := $(shell find src -type f -name '*.s')", 10
            db "PKG_OBJS := $(PKG_SRCS:$(PKG)/%.asm=$(BUILD)/$(PKG)/%.o)", 10
            db "APP_OBJS := $(APP_ASM:src/%.asm=$(BUILD)/%.o) $(APP_S:src/%.s=$(BUILD)/%.o)", 10
            db "OBJS     := $(PKG_OBJS) $(APP_OBJS)", 10, 10
            db "all: $(TARGET)", 10, 10
            db "$(TARGET): $(OBJS)", 10
            db 9, "$(LD) -o $@ $^", 10, 10
            db "$(BUILD)/$(PKG)/%.o: $(PKG)/%.asm | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) -o $@ $<", 10, 10
            db "$(BUILD)/%.o: src/%.asm | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) -o $@ $<", 10, 10
            db "$(BUILD)/%.o: src/%.s | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) -o $@ $<", 10, 10
            db "$(BUILD):", 10
            db 9, "mkdir -p $(BUILD)", 10, 10
            db "run: $(TARGET)", 10
            db 9, "./$(TARGET)", 10, 10
            db "clean:", 10
            db 9, "rm -rf $(BUILD)", 10, 10
            db ".PHONY: all run clean", 10, 0
