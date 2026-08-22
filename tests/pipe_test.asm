; cli/tests/pipe_test.asm - minimal pipe test, full flow with debug
%include "syscalls.inc"

section .data
    hello    db "HELLO", 0
    ok_str   db "OK:", 0
    nl       db 10, 0

section .bss
    pipe_fds resq 2
    buf      resb 64

section .text
global _start
_start:
    mov rax, SYS_pipe
    lea rdi, [pipe_fds]
    syscall
    ; print fds: pipe_fds[0] and pipe_fds[1]
    mov r13, rax
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [ok_str]
    mov rdx, 3
    syscall
    mov rdi, [pipe_fds]
    lea rsi, [buf + 16]
    call hex8
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [buf + 16]
    mov rdx, 8
    syscall
    mov rdi, [pipe_fds + 8]
    lea rsi, [buf + 16]
    call hex8
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [buf + 16]
    mov rdx, 8
    syscall
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [nl]
    mov rdx, 1
    syscall
    mov rax, SYS_exit
    mov rdi, 0
    syscall

hex8:
    mov rcx, 8
.loop:
    mov rdx, rdi
    and rdx, 0xF
    cmp rdx, 10
    jl .dig
    add rdx, 'a' - 10
    jmp .store
.dig:
    add rdx, '0'
.store:
    mov [rsi + rcx - 1], dl
    shr rdi, 4
    dec rcx
    jnz .loop
    ret
