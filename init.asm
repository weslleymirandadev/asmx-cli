; cli/init.asm - asmx_init: scaffold a new project in the CWD.
; 1) git clone <url> <name>   (the asmx framework, from GitHub by default)
; 2) boilerplate: src/main.asm, src/app/api/hello/route.s, Makefile

%include "syscalls.inc"

extern cli_git_clone
extern cli_write_file
extern cli_mkdir_p
extern cli_strlen
extern cli_strcpy

section .bss
    path_buf resb 1024

section .text

; asmx_init(rdi = package name, rsi = git url) -> rax = 0 ok, -1 err
global asmx_init
asmx_init:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi            ; pkg name
    mov r13, rsi            ; url

    ; boilerplate dirs
    lea rdi, [dir_src_hello]
    call cli_mkdir_p        ; src/app/api/hello

    ; fetch the framework: git clone <url> <name>
    mov rdi, r13
    mov rsi, r12
    call cli_git_clone
    test rax, rax
    jnz .err

    ; boilerplate files
    lea rdi, [path_main]
    lea rsi, [tpl_main]
    mov rdx, tpl_main_len
    call cli_write_file
    lea rdi, [path_route]
    lea rsi, [tpl_route]
    mov rdx, tpl_route_len
    call cli_write_file

    ; Makefile: mount "<mk1><name><mk2>" in path_buf
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
    jmp .done
.err:
    mov rax, -1
.done:
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
              db "    hello db '{" , 34, "hello" , 34, ": " , 34, "world" , 34, "}', 0", 10, 10
              db "route get_hello, 0", 10, 10
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
            db "# Next.js-style routing: route path derives from file location", 10
            db "#   src/app/page.s -> / | src/app/sobre/page.s -> /sobre |", 10
            db "#   src/app/api/hello/route.s -> /api/hello | src/app/not-found.s -> /__not_found", 10
            db "route_path = $(if $(filter src/app/not-found.s,$1),/__not_found,$(if $(filter src/app/page.s src/app/route.s,$1),/,$(patsubst src/app/%/page.s,/%,$(patsubst src/app/%/route.s,/%,$1))))", 10, 10
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
            db 9, "$(AS) $(ASFLAGS) -DROUTE_PATH=", 92, 34, "$(call route_path,$<)", 92, 34, " -o $@ $<", 10, 10
            db "$(BUILD):", 10
            db 9, "mkdir -p $(BUILD)", 10, 10
            db "run: $(TARGET)", 10
            db 9, "./$(TARGET)", 10, 10
            db "clean:", 10
            db 9, "rm -rf $(BUILD)", 10, 10
            db ".PHONY: all run clean", 10, 0
