build:
	mkdir -p build
	riscv64-elf-as kernel.s -fno-pic -march=rv64ia_zicsr_zifencei -o build/kernel.o -mno-relax
	riscv64-elf-ld build/kernel.o -o build/kernel.elf --no-relax-gp
	riscv64-elf-objcopy build/kernel.elf -O binary kernel.bin
qemu: build
	qemu-system-riscv64 -M virt -display none -serial stdio -kernel kernel.bin
dump: build
	riscv64-elf-objdump build/kernel.elf -d -M numeric > dump.txt
	# riscv64-elf-objdump kernel.elf -d -M numeric,no-aliases > dump.txt
clean:
	rm -rf build
	rm -f dump.txt out.txt kernel.bin
