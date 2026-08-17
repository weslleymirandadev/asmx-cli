; cli/fs.asm - filesystem helpers for the CLI (no libc)

%include "syscalls.inc"

; cli_mkdir_one(rdi = path) - mkdir, ignore EEXIST
global cli_mkdir_one
cli_mkdir_one:
    mov rax, SYS_mkdir
    mov rsi, 0o755
    syscall
    cmp rax, -17            ; EEXIST is fine
    je .ok
    test rax, rax
    js .fail
.ok:
    xor rax, rax
    ret
.fail:
    mov rax, -1
    ret

; cli_mkdir_p(rdi = path) - mkdir every path component (path is a dir).
; Temporarily zeroes the '/' chars, so path must be a writable buffer.
global cli_mkdir_p
cli_mkdir_p:
    push rbx
    push r12
    mov r12, rdi
    xor rbx, rbx
.loop:
    cmp byte [r12 + rbx], 0
    je .last
    cmp byte [r12 + rbx], '/'
    jne .next
    mov byte [r12 + rbx], 0
    mov rdi, r12
    call cli_mkdir_one
    mov byte [r12 + rbx], '/'
    test rax, rax
    js .err
.next:
    inc rbx
    jmp .loop
.last:
    mov rdi, r12
    call cli_mkdir_one
.err:
    pop r12
    pop rbx
    ret

; cli_write_file(rdi = path, rsi = data, rdx = len) -> 0 ok, -1 err
global cli_write_file
cli_write_file:
    push rbx
    push r12
    push r13
    mov rbx, rdi            ; path
    mov r12, rsi            ; data
    mov r13, rdx            ; len
    mov rax, SYS_openat
    mov rdi, -100           ; AT_FDCWD
    mov rsi, rbx
    mov rdx, 0x241          ; O_CREAT|O_WRONLY|O_TRUNC
    mov r10, 0o644          ; mode
    syscall
    test rax, rax
    js .err
    mov rbx, rax            ; fd
    mov rax, SYS_write
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    syscall
    mov r13, rax            ; bytes written (or -err)
    mov rax, SYS_close
    mov rdi, rbx
    syscall
    test r13, r13
    js .err
    xor rax, rax
    jmp .done
.err:
    mov rax, -1
.done:
    pop r13
    pop r12
    pop rbx
    ret
