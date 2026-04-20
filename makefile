RV64AS := $(shell which riscv64-elf-as || which riscv64-unknown-elf-as)
RV64LD := $(shell which riscv64-elf-ld || which riscv64-unknown-elf-ld)
RV64OBJCOPY := $(shell which riscv64-elf-objcopy || which riscv64-unknown-elf-objcopy)
RV64OBJDUMP := $(shell which riscv64-elf-objdump || which riscv64-unknown-elf-objdump)

build/%.o: src/%.s src/defs.s 
	mkdir -p build
	$(RV64AS) -march=rv64ia_zicsr_zifencei -mno-relax -o $@ $<

build/kernel.elf: build/boot.o build/kernel.o build/payload.o
	$(RV64LD) build/boot.o build/kernel.o build/payload.o -o build/kernel.elf --no-relax-gp -T link.ld
# $(RV64LD) build/kernel.o -o build/kernel_virt.elf --no-relax-gp -Ttext=0xffffffcaaaa80000

kernel.bin: build/kernel.elf
	$(RV64OBJCOPY) build/kernel.elf -O binary kernel.bin

.PHONY: all
all: kernel.bin

.PHONY: run
run: kernel.bin
	qemu-system-riscv64 -M virt -display none -serial stdio -kernel kernel.bin

.PHONY: debug
debug: kernel.bin
	qemu-system-riscv64 -M virt -display none -serial stdio -kernel kernel.bin -s -S

.PHONY: spike
spike: kernel.bin
	spike --rbb-port=9824 --kernel kernel.bin fw_jump.elf
	# openocd -f spike.cfg
	# gdb-multiarch

.PHONY: dump
dump: build/kernel.elf
	$(RV64OBJDUMP) build/kernel.elf -M no-aliases -d > dump.txt

.PHONY: clean
clean:
	rm -rf build
	rm -f dump.txt out.txt kernel.bin fw_jump.elf
