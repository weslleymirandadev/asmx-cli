AS      := nasm
LD      := ld
ROOT    := $(abspath ..)
BUILD   := $(ROOT)/build
TARGET  := $(BUILD)/asmx-cli   # not build/asmx (that is the package obj dir)

SRCS := cli/cli.asm cli/fs.asm cli/str.asm cli/init.asm cli/run.asm
OBJS := $(SRCS:cli/%.asm=$(BUILD)/cli/%.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) -o $@ $^

# NASM runs from the repo root so incbin paths in manifest.inc resolve
# (-I . for "asmx/..." sources, -I cli for the CLI's own includes).
$(BUILD)/cli/%.o: $(ROOT)/cli/%.asm $(ROOT)/cli/manifest.inc $(ROOT)/cli/syscalls.inc | $(BUILD)
	@mkdir -p $(dir $@)
	cd $(ROOT) && $(AS) -f elf64 -I . -I cli -o $(BUILD)/cli/$*.o cli/$*.asm

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: all clean
