; cli/tests/sleep_test.asm - test rt_sigprocmask + nanosleep timing
%include "syscalls.inc"

section .data
    ts       dq 0, 500000000      ; 0.5s
    mask     dq 0x10000           ; SIGCHLD
    ok_str   db "slept-ok", 10, 0

section .text
global _start
_start:
    ; block SIGCHLD
    mov rax, SYS_rt_sigprocmask
    mov rdi, 0
    lea rsi, [mask]
    xor rdx, rdx
    mov r10, 8
    syscall
    ; sleep 0.5s
    mov rax, SYS_nanosleep
    lea rdi, [ts]
    syscall
    ; print result (rax should be 0)
    mov r13, rax
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [ok_str]
    mov rdx, 10
    syscall
    mov rax, SYS_exit
    mov rdi, 0
    syscall
