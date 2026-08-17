AS      := nasm
LD      := ld
BUILD   := build
TARGET  := $(BUILD)/asmx

SRCS := cli.asm fs.asm str.asm init.asm run.asm
OBJS := $(SRCS:%.asm=$(BUILD)/%.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(LD) -o $@ $^

$(BUILD)/%.o: %.asm syscalls.inc | $(BUILD)
	@mkdir -p $(BUILD)
	$(AS) -f elf64 -I . -o $@ $<

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: all clean
