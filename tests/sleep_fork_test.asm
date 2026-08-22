; cli/tests/sleep_fork_test.asm - fork+wait (SIGCHLD) THEN block+nap:
; does the pending SIGCHLD still interrupt nanosleep after SIG_BLOCK?
%include "syscalls.inc"

section .data
    ts       dq 0, 800000000      ; 0.8s
    mask     dq 0x10000           ; SIGCHLD
    marker   db "S", 0
    done_str db "D", 10, 0

section .bss
    status   resq 1

section .text
global _start
_start:
    ; fork a child that exits immediately (generates SIGCHLD)
    mov rax, SYS_fork
    syscall
    test rax, rax
    jnz .parent
    mov rax, SYS_exit
    mov rdi, 0
    syscall
.parent:
    ; wait4 (reap) - SIGCHLD now pending
    mov r12, rax
    mov rax, SYS_wait4
    mov rdi, r12
    lea rsi, [status]
    xor rdx, rdx
    xor r10, r10
    syscall
    ; block SIGCHLD
    mov rax, SYS_rt_sigprocmask
    mov rdi, 0
    lea rsi, [mask]
    xor rdx, rdx
    mov r10, 8
    syscall
    ; nap 0.8s - measure if it returns early
    mov rax, SYS_nanosleep
    lea rdi, [ts]
    syscall
    ; print result (rax=0 means full sleep, -EINTR means interrupted)
    mov r13, rax
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [done_str]
    mov rdx, 2
    syscall
    mov rax, SYS_exit
    mov rdi, 0
    syscall
