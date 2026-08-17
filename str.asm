; cli/str.asm - minimal string helpers for the CLI (no libc)

; cli_strcmp(rdi = a, rsi = b) -> rax = 0 if equal
global cli_strcmp
cli_strcmp:
    xor ecx, ecx
.loop:
    mov al, [rdi + rcx]
    mov dl, [rsi + rcx]
    cmp al, dl
    jne .diff
    test al, al
    jz .eq
    inc rcx
    jmp .loop
.diff:
    mov rax, 1
    ret
.eq:
    xor rax, rax
    ret

; cli_strlen(rdi = s) -> rax = length
global cli_strlen
cli_strlen:
    xor eax, eax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret

; cli_strcpy(rdi = dest, rsi = src) -> rax = dest
global cli_strcpy
cli_strcpy:
    push rdi
.loop:
    mov al, [rsi]
    mov [rdi], al
    test al, al
    jz .done
    inc rdi
    inc rsi
    jmp .loop
.done:
    pop rax
    ret
