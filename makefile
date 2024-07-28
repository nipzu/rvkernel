RV64AS := $(shell which riscv64-elf-as || which riscv64-unknown-elf-as)
RV64LD := $(shell which riscv64-elf-ld || which riscv64-unknown-elf-ld)
RV64OBJCOPY := $(shell which riscv64-elf-objcopy || which riscv64-unknown-elf-objcopy)
RV64OBJDUMP := $(shell which riscv64-elf-objdump || which riscv64-unknown-elf-objdump)

build: kernel.s
	mkdir -p build
	$(RV64AS) kernel.s -march=rv64ia_zicsr_zifencei -mno-relax -o build/kernel.o
	$(RV64LD) build/kernel.o -o build/kernel.elf --no-relax-gp -Ttext=0x80200000
	$(RV64LD) build/kernel.o -o build/kernel_virt.elf --no-relax-gp -Ttext=0xffffffcaaaa80000
	$(RV64OBJCOPY) build/kernel.elf -O binary kernel.bin
run: build
	qemu-system-riscv64 -M virt -display none -serial stdio -kernel kernel.bin
debug: build
	qemu-system-riscv64 -M virt -display none -serial stdio -kernel kernel.bin -s -S
spike: build
	spike --rbb-port=9824 --kernel kernel.bin fw_jump.elf
	# openocd -f spike.cfg
	# gdb-multiarch
dump: build
	$(RV64OBJDUMP) build/kernel.elf -d > dump.txt
	# $(RV64OBJDUMP) build/kernel.elf -d -M numeric > dump.txt
	# $(RV64OBJDUMP) kernel.elf -d -M numeric,no-aliases > dump.txt
clean:
	rm -rf build
	rm -f dump.txt out.txt kernel.bin
