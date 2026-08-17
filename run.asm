; cli/run.asm - build, dev and git clone commands (fork + exec, no libc)

%include "syscalls.inc"

section .data
    path_make   db "/usr/bin/make", 0
    make_str    db "make", 0
    argv_make   dq make_str, 0
    path_git    db "/usr/bin/git", 0
    git_str     db "git", 0
    clone_str   db "clone", 0
    path_server db "./build/server", 0
    server_str  db "./build/server", 0
    argv_server dq server_str, 0
    env_path    db "PATH=/usr/bin:/bin", 0
    envp        dq env_path, 0

section .bss
    wait_status resq 1
    argv_buf    resq 8

section .text

; cli_exec(rdi = path, rsi = argv) -> rax = exit code
cli_exec:
    push r12
    push r13
    mov r12, rdi            ; path
    mov r13, rsi            ; argv
    mov rax, SYS_fork
    syscall
    test rax, rax
    jnz .parent
    ; child: exec
    mov rax, SYS_execve
    mov rdi, r12
    mov rsi, r13
    lea rdx, [envp]
    syscall
    mov rax, SYS_exit
    mov rdi, 127
    syscall
.parent:
    mov r12, rax            ; child pid
    mov rax, SYS_wait4
    mov rdi, r12
    lea rsi, [wait_status]
    xor rdx, rdx
    xor r10, r10
    syscall
    mov rax, [wait_status]
    shr rax, 8
    and rax, 0xFF
    pop r13
    pop r12
    ret

; cli_run_build() -> rax = make exit code
global cli_run_build
cli_run_build:
    lea rdi, [path_make]
    lea rsi, [argv_make]
    call cli_exec
    ret

; cli_git_clone(rdi = url, rsi = dir) -> rax = 0 ok, else git exit code
global cli_git_clone
cli_git_clone:
    lea rax, [argv_buf]
    lea rbx, [git_str]
    mov [rax], rbx
    lea rbx, [clone_str]
    mov [rax + 8], rbx
    mov [rax + 16], rdi    ; url
    mov [rax + 24], rsi    ; dir
    mov qword [rax + 32], 0
    lea rdi, [path_git]
    lea rsi, [argv_buf]
    call cli_exec
    ret

; cli_run_dev() - build, then exec the server (never returns on success)
global cli_run_dev
cli_run_dev:
    call cli_run_build
    test rax, rax
    jnz .build_failed
    mov rax, SYS_execve
    lea rdi, [path_server]
    lea rsi, [argv_server]
    lea rdx, [envp]
    syscall
    mov rax, SYS_exit
    mov rdi, 127
    syscall
.build_failed:
    mov rdi, rax
    mov rax, SYS_exit
    syscall
