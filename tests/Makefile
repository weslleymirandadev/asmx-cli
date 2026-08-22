# cli/tests/Makefile - standalone diagnostics for the syscall patterns the
# dev loop depends on. Each test is a tiny freestanding ELF (nasm+ld, no
# libc). These document bugs that were mordidas in production:
#
#   pipe_test        - pipe() writes TWO 32-bit ints (fd[1] is at +4, NOT +8)
#                      -> reading a qword at +8 yields fd 0 (stdin!) and the
#                      read blocks forever. Fixed with `mov edi, dword [...+4]`.
#   capture_test     - full pipe+fork+dup2 stderr capture pattern used by
#                      cli_exec_capture.
#   sleep_test       - nanosleep + rt_sigprocmask(SIG_BLOCK) baseline: 0.5s.
#   sleep_fork_test  - SIGCHLD from a reaped child would EINTR nanosleep;
#                      blocking SIGCHLD around the sleep fixes it (0.8s full).
#   sleep_eintr_test - proof of the bug: 1.2e9 tv_nsec is INVALID (> 1e9),
#                      nanosleep returns -EINVAL instantly -> busy loop.

TESTS := pipe_test capture_test sleep_test sleep_fork_test

all: $(TESTS)

%: %.asm ../syscalls.inc
	@mkdir -p build
	nasm -f elf64 -I .. -o build/$@.o $*.asm
	ld -o build/$@ build/$@.o

run: all
	@for t in $(TESTS); do echo "== $$t =="; timeout 3 ./build/$$t && echo "  OK"; done

clean:
	rm -rf build

.PHONY: all run clean
