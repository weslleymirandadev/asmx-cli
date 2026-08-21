; cli/init.asm - asx_init: scaffold a new project in the CWD.
; 1) git clone <url> <name>   (the asx framework, from GitHub by default)
; 2) boilerplate: src/main.asx, src/app/api/hello/route.asx, Makefile

%include "syscalls.inc"

extern cli_git_clone
extern cli_write_file
extern cli_mkdir_p
extern cli_strlen
extern cli_strcpy

section .bss
    path_buf resb 4096

section .text

; asx_init(rdi = package name, rsi = git url) -> rax = 0 ok, -1 err
global asx_init
asx_init:
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
    lea rdi, [path_page]
    lea rsi, [tpl_page]
    mov rdx, tpl_page_len
    call cli_write_file
    lea rdi, [path_mw]
    lea rsi, [tpl_mw]
    mov rdx, tpl_mw_len
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
    path_main     db "src/main.asx", 0
    path_route    db "src/app/api/hello/route.asx", 0
    path_page     db "src/app/page.asx", 0
    path_mw       db "src/middleware.asx", 0
    path_makefile db "Makefile", 0

    tpl_main db "; src/main.asx - asx app entry", 10
             db "; (asx.inc is pre-included by the Makefile - no %include needed)", 10, 10
             db "section .text", 10
             db "global _start", 10
             db "_start:", 10
             db "    asx.listen 3000", 10
             db "    jmp route_dispatch", 10, 0
    tpl_main_len equ $ - tpl_main - 1

    tpl_route db "; src/app/api/hello/route.asx", 10
              db "; (asx.inc is pre-included by the Makefile - no %include needed)", 10, 10
              db "section .data", 10
              db "    hello db '{" , 34, "hello" , 34, ": " , 34, "world" , 34, "}', 0", 10, 10
              db "route.get get_hello", 10, 10
              db "section .GET", 10
              db "get_hello:", 10
              db "    res.json hello", 10
              db "    asx.next", 10, 0
    tpl_route_len equ $ - tpl_route - 1

    tpl_page db "; src/app/page.asx", 10
             db "; GET / -> home page, server-side rendered.", 10, 10
             db "section .data", 10
             db "    index_content:", 10
             db "        @theme bg #0b0e14 text #e2e8f0 accent #f97316", 10
             db "        @main min-h-screen p-8", 10
             db "            state count: int = 0", 10
             db "            @h1 text-4xl font-extrabold text-orange-500:", 10
             db "                ", 34, "Hello from Assembly", 34, 10
             db "            @p text-gray-400 mt-4:", 10
             db "                ", 34, "Server in Assembly. UI in WebAssembly.", 34, 10
             db "            @button bg-orange-500 mt-6 p-3 rounded-xl font-bold onclick=", 34, "count++", 34, ":", 10
             db "                ", 34, "Clicked {count} times", 34, 10
             db "        @end", 10, 10
             db "page get_index", 10, 10
             db "section .SERVER", 10
             db "get_index:", 10
             db "    res.content index_content", 10
             db "    asx.next", 10, 0
    tpl_page_len equ $ - tpl_page - 1

    tpl_mw db "; src/middleware.asx", 10
           db "; Pass-through middleware (runs before routing for every request).", 10
           db "; End with mw.next to continue, mw.redirect ", 34, "path", 34, " to 302, etc.", 10, 10
           db "middleware mw_pass", 10, 10
           db "section .MIDDLEWARE", 10
           db "mw_pass:", 10
           db "    mw.next", 10, 0
    tpl_mw_len equ $ - tpl_mw - 1

    tpl_mk1 db "AS      := nasm", 10
            db "LD      := ld", 10
            db "WAT2WASM := wat2wasm", 10
            db "PKG     := ", 0

    tpl_mk2 db 10
            db "ASFLAGS := -f elf64 -I $(PKG) -I src", 10
            db "# App files (.asx) get asx.inc pre-included by the Makefile (NASM -P):", 10
            db "# no need to write %include ", 34, "asx.inc", 34, " in every src file. The", 10
            db "# framework (asx/**) and the ui-compile tool do NOT get it", 10
            db "# (they declare their own externs). Idempotent with manual includes", 10
            db "# thanks to the %ifndef guard in asx.inc.", 10
            db "APP_INC := -P$(PKG)/asx.inc", 10
            db "BUILD   := build", 10
            db "TARGET  := $(BUILD)/server", 10
            db "UI_LIB  := $(PKG)/wasm/draw.wat $(PKG)/wasm/text.wat $(PKG)/wasm/widgets.wat $(PKG)/wasm/components.wat", 10, 10
            db "# Zero-maintenance: every .asm in the package and every .asx under src/", 10
            db "# is picked up automatically. No Makefile edits for new folders or routes.", 10
            db "# Exception: asx/ui/ e a BUILD TOOL (compilador da DSL @, entry", 10
            db "# compile.asm + modules = one assembly unit) - never in the server.", 10
            db "PKG_SRCS := $(shell find $(PKG) -name '*.asm' ! -path '$(PKG)/ui/*' ! -path '$(PKG)/tests/*')", 10
            db "APP_ASM  := $(shell find src -type f -name '*.asm')", 10
            db "APP_S    := $(shell find src -type f -name '*.asx' ! -path 'src/components/*' ! -name 'middleware.asx')", 10
            db "MW_S     := $(wildcard src/middleware.asx)", 10
            db "PKG_OBJS := $(PKG_SRCS:$(PKG)/%.asm=$(BUILD)/$(PKG)/%.o)", 10
            db "APP_OBJS := $(APP_ASM:src/%.asm=$(BUILD)/%.o) $(APP_S:src/%.asx=$(BUILD)/%.o) $(MW_S:src/%.asx=$(BUILD)/%.o)", 10
            db "OBJS     := $(PKG_OBJS) $(APP_OBJS)", 10, 10
            db "# Next.js-style routing: route path derives from file location", 10
            db "#   src/app/page.asx -> / | src/app/about/page.asx -> /about |", 10
            db "#   src/app/api/hello/route.asx -> /api/hello | src/app/not-found.asx -> /__not_found", 10
            db "route_path = $(if $(filter src/app/not-found.asx,$1),/__not_found,$(if $(filter src/app/page.asx src/app/route.asx,$1),/,$(patsubst src/app/%/page.asx,/%,$(patsubst src/app/%/route.asx,/%,$1))))", 10, 10
            db "all: $(TARGET) $(UI_WASMS)", 10, 10
            db "# WebAssembly: each @ block in a page.asx becomes a .wat (ui-compile);", 10
            db "# the page final module = framework lib + the component .wat files", 10
            db "# + _main, linked via cat -> wat2wasm (no python). Each route .wasm", 10
            db "# mirrors the Next.js convention (app/about/page.tsx):", 10
            db "# src/app/about/page.asx -> static/about/page.wasm (/about/page.wasm);", 10
            db "# the root (src/app/page.asx) is the exception: static/index.wasm.", 10
            db "ui_name = $(if $(filter src/app/page.asx,$1),index,$(patsubst %/page.asx,%,$(patsubst src/app/%,%,$1)))", 10
            db "ui_wasm = $(if $(filter src/app/page.asx,$1),static/index.wasm,static/$(call ui_name,$1)/page.wasm)", 10
            db "UI_WASMS := $(foreach s,$(filter %/page.asx,$(APP_S)),$(call ui_wasm,$(s)))", 10, 10
            db "$(BUILD)/%.s.wasm: $(BUILD)/%.s $(wildcard $(BUILD)/%.s.d/*.wat) $(UI_LIB)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "{ echo ", 34, "(module", 34, "; cat $(UI_LIB) $(wildcard $(BUILD)/$*.s.d/*.wat); echo ", 34, ")", 34, "; } | $(WAT2WASM) - -o $@", 10, 10
            db "# static/<ui_name>[/page].wasm <- build/<page>.s.wasm (root = index.wasm)", 10
            db "$(foreach s,$(filter %/page.asx,$(APP_S)),$(eval $(call ui_wasm,$(s)): $(BUILD)/$(patsubst src/%.asx,%.s.wasm,$(s)) ; @mkdir -p $$(dir $$@) && cp $$< $$@))", 10, 10
            db "static:", 10
            db 9, "mkdir -p static", 10, 10
            db "$(TARGET): $(OBJS)", 10
            db 9, "$(LD) -o $@ $^", 10, 10
            db "$(BUILD)/$(PKG)/%.o: $(PKG)/%.asm | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) -o $@ $<", 10, 10
            db "$(BUILD)/%.o: src/%.asm | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) $(APP_INC) -o $@ $<", 10, 10
            db "# src/middleware.asx - the middleware (Next.js middleware.ts style).", 10
            db "# NOT a route: no ROUTE_PATH, just assembles into the `middleware` linker", 10
            db "# section the router scans before dispatching.", 10
            db "$(BUILD)/middleware.o: src/middleware.asx | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) $(APP_INC) -o $@ $<", 10, 10
            db "# page.asx @ DSL -> NASM data + .wat por componente (ui/*.asm, no python):", 10
            db "# the @ block becomes an HTML shell (data-modules) in the build/*.s and a .wat in", 10
            db "# build/<page>.s.d/. Files without @ pass through.", 10
            db "UI_CP := $(BUILD)/tools/ui-compile", 10, 10
            db "UI_CP_SRC := $(PKG)/ui/compile.asm $(shell find $(PKG)/ui -name '*.asm' -o -name '*.inc')", 10, 10
            db "$(UI_CP): $(UI_CP_SRC) | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(AS) $(ASFLAGS) -o $(BUILD)/tools/ui-compile.o $<", 10
            db 9, "$(LD) -o $@ $(BUILD)/tools/ui-compile.o", 10, 10
            db "# @comp components (src/components/*.asx): any change rebuilds every page.asx", 10
            db "COMP_SRCS := $(wildcard src/components/*.asx)", 10
            db "$(BUILD)/%.s: src/%.asx $(UI_CP) $(COMP_SRCS) | $(BUILD)", 10
            db 9, "@mkdir -p $(dir $@)", 10
            db 9, "$(UI_CP) $< $@", 10, 10
            db "$(BUILD)/%.o: $(BUILD)/%.s | $(BUILD)", 10
            db 9, "$(AS) $(ASFLAGS) $(APP_INC) -DROUTE_PATH=", 92, 34, "$(call route_path,$(patsubst $(BUILD)/%.s,src/%.asx,$<))", 92, 34, " -o $@ $<", 10, 10
            db "$(BUILD):", 10
            db 9, "mkdir -p $(BUILD)", 10, 10
            db "run: $(TARGET)", 10
            db 9, "./$(TARGET)", 10, 10
            db "clean:", 10
            db 9, "rm -rf $(BUILD)", 10, 10
            db ".PHONY: all run clean", 10, 0
