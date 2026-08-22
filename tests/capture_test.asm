; cli/tests/capture_test.asm - the cli_exec_capture pattern: pipe+fork,
; child stderr dup2'd into the pipe, parent reads until EOF. A command
; that writes to STDERR (/bin/sh -c "echo oi >&2") must be captured.
; Exits 0 if "oi" arrives; 124/timeout = the pipe read deadlocked.
%include "syscalls.inc"

section .data
    path_sh  db "/bin/sh", 0
    sh_str   db "sh", 0
    c_str    db "-c", 0
    cmd_str  db "echo oi >&2", 0
    argv     dq sh_str, c_str, cmd_str, 0
    env_path db "PATH=/usr/bin:/bin", 0
    envp     dq env_path, 0
    marker   db "CAPTURED:", 0
    nl       db 10, 0

section .bss
    pipe_fds resq 2
    buf      resb 256
    status   resq 1

section .text
global _start
_start:
    mov rax, SYS_pipe
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    js .fail
    mov rax, SYS_fork
    syscall
    test rax, rax
    jnz .parent
    ; child: dup2(pipe_fds[1], 2) then exec sh -c "echo oi >&2"
    mov rax, SYS_dup2
    mov edi, dword [pipe_fds + 4]   ; 32-bit int! (+4, NOT +8)
    mov rsi, 2
    syscall
    mov rax, SYS_execve
    lea rdi, [path_sh]
    lea rsi, [argv]
    lea rdx, [envp]
    syscall
    mov rax, SYS_exit
    mov rdi, 127
    syscall
.parent:
    mov r12, rax
    ; close write end in the parent so read sees EOF
    mov rax, SYS_close
    mov edi, dword [pipe_fds + 4]
    syscall
    xor r13, r13
.read:
    mov rax, SYS_read
    mov edi, dword [pipe_fds]       ; read end (32-bit int!)
    lea rsi, [buf + r13]
    mov rdx, 256
    sub rdx, r13
    syscall
    test rax, rax
    jle .read_done
    add r13, rax
    jmp .read
.read_done:
    ; wait for the child
    mov rax, SYS_wait4
    mov rdi, r12
    lea rsi, [status]
    xor rdx, rdx
    xor r10, r10
    syscall
    ; print what was captured
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [marker]
    mov rdx, 9
    syscall
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [buf]
    mov rdx, r13
    syscall
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [nl]
    mov rdx, 1
    syscall
    ; exit 0 only if we got the "oi" from stderr
    cmp r13, 3
    jl .fail
    mov rax, SYS_exit
    mov rdi, 0
    syscall
.fail:
    mov rax, SYS_exit
    mov rdi, 1
    syscall
