; cli/syscalls.inc - syscall numbers used by the asmx CLI (self-contained)
%ifndef CLI_SYSCALLS_INC
%define CLI_SYSCALLS_INC
%define SYS_write    1
%define SYS_close    3
%define SYS_fork     57
%define SYS_exit     60
%define SYS_execve   59
%define SYS_wait4    61
%define SYS_kill     62
%define SYS_nanosleep 35
%define SYS_mkdir    83
%define SYS_openat   257
%endif
