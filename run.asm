; cli/run.asm - build, dev and git clone commands (fork + exec, no libc)

%include "syscalls.inc"

extern cli_write_file

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
    err_file_path db "build/asx-error.txt", 0
    sigchld_mask dq 0x10000        ; bit 16 = SIGCHLD (17)

section .bss
    wait_status resq 1
    argv_buf    resq 8
    ; build output capture (stderr of make + ui-compile), for the
    ; formatted error shown once and for build/asx-error.txt
    pipe_fds    resq 2
    build_err_buf resb 8192
    build_err_len resq 1
    build_err_last resb 8192
    build_err_last_len resq 1
    sleep_ts     resq 2        ; scratch timespec for nanosleep

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

; cli_run_build() -> rax = make exit code, build_err_buf = make stderr
global cli_run_build
cli_run_build:
    lea rdi, [path_make]
    lea rsi, [argv_make]
    call cli_exec_capture
    ret

; cli_exec_capture(rdi = path, rsi = argv) -> rax = exit code
; Like cli_exec, but the child's stderr (fd 2) is redirected to a pipe
; and read into build_err_buf/build_err_len. Used by the dev loop so a
; failed build's message can be shown once and written to
; build/asx-error.txt for the frontend overlay.
cli_exec_capture:
    push r12
    push r13
    push r14
    mov r12, rdi                ; path
    mov r13, rsi                ; argv
    ; pipe(pipe_fds) - the kernel writes TWO 32-bit ints (fd[0], fd[1])
    mov rax, SYS_pipe
    lea rdi, [pipe_fds]
    syscall
    test rax, rax
    js .err
    mov rax, SYS_fork
    syscall
    test rax, rax
    jnz .parent
    ; child: dup2(pipe_fds[1], 2) then exec
    mov rax, SYS_dup2
    mov edi, dword [pipe_fds + 4] ; write end (32-bit int!)
    mov rsi, 2                  ; stderr
    syscall
    mov rax, SYS_execve
    mov rdi, r12
    mov rsi, r13
    lea rdx, [envp]
    syscall
    mov rax, SYS_exit
    mov rdi, 127
    syscall
.parent:
    mov r14, rax                ; child pid
    ; close the write end in the parent (so read sees EOF)
    mov rax, SYS_close
    mov edi, dword [pipe_fds + 4]
    syscall
    ; read stderr into build_err_buf (up to 8192)
    xor r12, r12                ; total
.read:
    cmp r12, 8192
    jge .read_done
    mov rax, SYS_read
    mov edi, dword [pipe_fds]   ; read end (32-bit int!)
    lea rsi, [build_err_buf + r12]
    mov rdx, 8192
    sub rdx, r12
    syscall
    test rax, rax
    jle .read_done
    add r12, rax
    jmp .read
.read_done:
    mov [build_err_len], r12
    mov rax, SYS_close
    mov edi, dword [pipe_fds]
    syscall
    ; wait for the child
    mov rax, SYS_wait4
    mov rdi, r14
    lea rsi, [wait_status]
    xor rdx, rdx
    xor r10, r10
    syscall
    mov rax, [wait_status]
    shr rax, 8
    and rax, 0xFF
    pop r14
    pop r13
    pop r12
    ret
.err:
    mov rax, -1
    pop r14
    pop r13
    pop r12
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
; dependency: src/**, ui modules, components). On any change it
; rebuilds FIRST; only if the build succeeds does it kill the server
; and respawn (a crashed server is respawned too). A FAILED build
; prints the error and EXITS immediately (fail-fast, no retry loop) -
; the dev fixes the source and runs `asx dev` again.
global cli_run_dev
cli_run_dev:
    push r12
    call cli_run_build
    test rax, rax
    jnz .initial_fail
    call dev_spawn_server       ; rax = server pid
    mov r12, rax
    jmp .loop
.initial_fail:
    ; the very first build failed: print the error and die (no server
    ; was spawned yet, so nothing to kill)
    call dev_show_error
    mov rax, SYS_exit
    mov rdi, 1
    syscall
.loop:
    ; sleep 400ms (SIGCHLD from the make child interrupts nanosleep with
    ; EINTR, so SIGCHLD is blocked around the sleep and unblocked after)
    lea rsi, [dev_ts]
.load_ts:
    lea rdi, [sleep_ts]         ; dst
    mov rdx, 16
    call memcpy_buf
    ; block SIGCHLD (sig 17 -> bit 16 -> mask 0x10000)
    mov rax, SYS_rt_sigprocmask
    mov rdi, 0                  ; SIG_BLOCK
    lea rsi, [sigchld_mask]
    xor rdx, rdx                ; oldset = NULL
    mov r10, 8                  ; sigsetsize
    syscall
.sleep:
    lea rdi, [sleep_ts]
    mov rax, SYS_nanosleep
    syscall
    ; unblock SIGCHLD
    mov rax, SYS_rt_sigprocmask
    mov rdi, 1                  ; SIG_UNBLOCK
    lea rsi, [sigchld_mask]
    xor rdx, rdx
    mov r10, 8
    syscall
    ; server died? respawn (crash recovery) - except when it exited with
    ; code 1 (no free port found): propagate the failure and stop
    test r12, r12
    jz .alive                   ; no server yet (initial build failed)
    mov rdi, r12
    call dev_check_server
    test rax, rax
    jz .alive
    cmp rax, 2
    je dev_give_up
    call dev_spawn_server
    mov r12, rax
.alive:
    ; anything to rebuild? make -q: 0 = up-to-date, 1 = changed, 2 = error
    call dev_make_q
    cmp rax, 1
    je .rebuild
    jmp .loop
.rebuild:
    ; build FIRST, capture stderr. Only touch the server on success.
    call cli_run_build
    test rax, rax
    jnz .build_failed
    ; build OK: clear the error file, kill + respawn the server
    lea rdi, [err_file_path]
    call dev_unlink
    mov rdi, r12
    call dev_kill_server
    call dev_spawn_server
    mov r12, rax
    jmp .loop
.build_failed:
    ; FAIL-FAST: print the error, kill the server (last good build is no
    ; longer trustworthy - the source is broken) and exit. No retry loop.
    call dev_show_error
    mov rdi, r12
    call dev_kill_server
    mov rax, SYS_exit
    mov rdi, 1
    syscall

; dev_show_error() - prints build_err_buf to stderr only if it differs
; from the last shown error, and writes build/asx-error.txt for the
; frontend overlay.
dev_show_error:
    push r12
    push r13
    ; differs from the last shown?
    mov r12, [build_err_len]
    mov r13, [build_err_last_len]
    cmp r12, r13
    jne .diff
    lea rdi, [build_err_buf]
    lea rsi, [build_err_last]
    mov rdx, r12
    call memcmp_buf
    test rax, rax
    jz .write_file              ; same -> only refresh the file
.diff:
    ; print to stderr
    mov rax, SYS_write
    mov rdi, 2
    lea rsi, [build_err_buf]
    mov rdx, r12
    syscall
    ; remember it
    lea rdi, [build_err_last]
    lea rsi, [build_err_buf]
    mov rdx, r12
    call memcpy_buf
    mov [build_err_last_len], r12
.write_file:
    ; write build/asx-error.txt (frontend overlay)
    lea rdi, [err_file_path]
    lea rsi, [build_err_buf]
    mov rdx, [build_err_len]
    call cli_write_file
    pop r13
    pop r12
    ret

; memcmp_buf(rdi = a, rsi = b, rdx = n) -> rax = 0 if equal
memcmp_buf:
    xor rcx, rcx
.loop:
    cmp rcx, rdx
    jge .eq
    mov al, [rdi + rcx]
    mov r8b, [rsi + rcx]
    cmp al, r8b
    jne .ne
    inc rcx
    jmp .loop
.eq:
    xor rax, rax
    ret
.ne:
    mov rax, 1
    ret

; memcpy_buf(rdi = dst, rsi = src, rdx = n)
memcpy_buf:
    xor rcx, rcx
.loop:
    cmp rcx, rdx
    jge .done
    mov al, [rsi + rcx]
    mov [rdi + rcx], al
    inc rcx
    jmp .loop
.done:
    ret

; dev_unlink(rdi = path)
dev_unlink:
    mov rax, SYS_unlink
    syscall
    ret

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

; dev_check_server(rdi = pid) -> rax = 0 alive, 1 dead (respawn),
; 2 dead with exit code 1 (no free port - do NOT respawn, propagate)
global dev_check_server        ; exposed for the dev_check test driver
dev_check_server:
    test rdi, rdi
    jz .dead
    mov rax, SYS_wait4
    lea rsi, [wait_status]
    mov rdx, 1                  ; WNOHANG
    xor r10, r10
    syscall
    test rax, rax
    jnz .got_status
    xor rax, rax                ; still alive
    ret
.got_status:
    mov rax, [wait_status]
    shr rax, 8
    and rax, 0xFF
    cmp rax, 1
    je .fatal
    mov rax, 1                  ; dead - respawn
    ret
.fatal:
    mov rax, 2                  ; dead with exit 1 - give up
    ret
.dead:
    mov rax, 1
    ret

; dev_give_up() - the server exited with code 1 (no free port up to the
; retry ceiling): the message was already printed by the server, stop
; instead of respawning it forever
dev_give_up:
    mov rax, SYS_exit
    mov rdi, 1
    syscall

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
