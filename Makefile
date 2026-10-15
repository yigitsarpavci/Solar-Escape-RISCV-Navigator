# ==============================================================================
# Solar Escape: RISC-V Westward Flight Navigator Makefile
# ==============================================================================

TOOLCHAIN ?= riscv64-unknown-elf-
AS        := $(TOOLCHAIN)as
LD        := $(TOOLCHAIN)ld
SPIKE     := spike

ARCH_FLAGS := -march=rv32i -mabi=ilp32
LDFLAGS    := -m elf32lriscv -T linker.ld --no-relax

SRC_DIR    := src
BUILD_DIR  := build
TARGET     := $(BUILD_DIR)/flight_navigator.elf

SRCS       := $(SRC_DIR)/flight_navigator.s
OBJS       := $(BUILD_DIR)/flight_navigator.o

# Spike memory configuration: ROM at 0x80000000 (64K), RAM at 0x80010000 (64K)
SPIKE_FLAGS := -m0x80000000:0x20000

.PHONY: all clean run debug docker-build docker-run

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJS): $(SRCS) | $(BUILD_DIR)
	$(AS) $(ARCH_FLAGS) -o $@ $<

$(TARGET): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) -o $@ $<

clean:
	rm -rf $(BUILD_DIR)

run: $(TARGET)
	$(SPIKE) $(SPIKE_FLAGS) $(TARGET)

debug: $(TARGET)
	$(SPIKE) -d $(SPIKE_FLAGS) $(TARGET)

# Run inside CMPE 344 Docker container
docker-build:
	docker run --rm -v $$(CURDIR):/workspace -w /workspace ghcr.io/bouncmpe/labs344 make all

docker-run:
	docker run -it --rm -v $$(CURDIR):/workspace -w /workspace ghcr.io/bouncmpe/labs344 make run
