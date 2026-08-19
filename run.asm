; cli/run.asm - build, dev and git clone commands (fork + exec, no libc)

%include "syscalls.inc"

section .data
    path_make   db "/usr/bin/make", 0
    make_str    db "make", 0
    q_str       db "-q", 0
    argv_make   dq make_str, 0
    argv_make_q dq make_str, q_str, 0
    path_git    db "/usr/bin/git", 0
    git_str     db "git", 0
    clone_str   db "clone", 0
    path_server db "./build/server", 0
    server_str  db "./build/server", 0
    argv_server dq server_str, 0
    env_path    db "PATH=/usr/bin:/bin", 0
    envp        dq env_path, 0
    clear_seq   db 27, '[', '2', 'J', 27, '[', 'H'   ; ANSI clear screen + cursor home
    clear_seq_len equ $ - clear_seq
    dev_ts      dq 0, 400000000      ; nanosleep timespec: 0.4s

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

; cli_run_dev() - build, serve and HOT-RELOAD.
; Spawns the server, then polls `make -q` (the Makefile knows every
; dependency: src/**, ui modules, components). On any change it kills
; the server, rebuilds, clears the console and respawns. A crashed
; server is respawned too. Never returns.
global cli_run_dev
cli_run_dev:
    push r12
    call cli_run_build
    call dev_spawn_server       ; rax = server pid
    mov r12, rax
.loop:
    ; sleep 400ms (dev_ts is untouched by nanosleep)
    lea rdi, [dev_ts]
    mov rax, SYS_nanosleep
    syscall
    ; server died? respawn (crash recovery)
    mov rdi, r12
    call dev_check_server
    test rax, rax
    jz .alive
    call dev_spawn_server
    mov r12, rax
.alive:
    ; anything to rebuild? make -q: 0 = up-to-date, 1 = changed, 2 = error
    call dev_make_q
    cmp rax, 1
    je .rebuild
    jmp .loop
.rebuild:
    mov rdi, r12
    call dev_kill_server
    call cli_run_build
    call dev_spawn_server
    mov r12, rax
    jmp .loop

; dev_make_q() -> rax = `make -q` exit code (0 up-to-date, 1 changed, 2 error)
dev_make_q:
    lea rdi, [path_make]
    lea rsi, [argv_make_q]
    call cli_exec
    ret

; dev_spawn_server() -> rax = child pid (the child execs ./build/server)
dev_spawn_server:
    mov rax, SYS_fork
    syscall
    test rax, rax
    jnz .parent
    mov rax, SYS_execve
    lea rdi, [path_server]
    lea rsi, [argv_server]
    lea rdx, [envp]
    syscall
    mov rax, SYS_exit
    mov rdi, 127
    syscall
.parent:
    ret

; dev_check_server(rdi = pid) -> rax = pid if dead, 0 if still alive
dev_check_server:
    test rdi, rdi
    jz .dead
    mov rax, SYS_wait4
    lea rsi, [wait_status]
    mov rdx, 1                  ; WNOHANG
    xor r10, r10
    syscall
    test rax, rax
    jnz .dead
    xor rax, rax
    ret
.dead:
    mov rax, -1
    ret

; dev_kill_server(rdi = pid) - SIGTERM + reap
dev_kill_server:
    push r12
    mov r12, rdi
    test r12, r12
    jz .done
    mov rax, SYS_kill
    mov rdi, r12
    mov rsi, 15                 ; SIGTERM
    syscall
    mov rax, SYS_wait4
    mov rdi, r12
    lea rsi, [wait_status]
    xor rdx, rdx
    xor r10, r10
    syscall
.done:
    pop r12
    ret

.build_failed:
    mov rdi, rax
    mov rax, SYS_exit
    syscall
