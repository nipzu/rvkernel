This project is a small microkernel for the RISC-V architecture. A minimal bootloader is also planned. 

The code is written in 64-bit RISC-V assembly using the GNU assembler. The code can only used the base instruction set and the A (atomics) extension. The kernel code run in S-mode (supervisor). The kernel can use the RISC-V SBI (Supervisor Binary Interface).

A distinguishing feature of the kernel is that kernel code does not use an execution stack. Instead, all state is stored in registers and object pages.

The main objects the kernel handles are Executors and Virtual Address Spaces (VAS). Executors are like threads: they execute code and are scheduled by the kernel. Each executor has some (possibly shared) VAS object that determines the virtual memory map.

# Project structure

## Documentation

Documentation relating to the project is located at `./docs`. At the time of writing, it consists of the following files:
- `Kernel common.md`: This files specifies the register usage convention of the kernel code, and the logical structure and contents of kernel objects such as Executors. Each of these objects is allocated a single 4 KB page. 
- `Memory.md`: This file has some initial plans for how kernel memory management should work.
- `Syscalls.md`: This file contains a list of system calls supported by the kernel, and a short description of the calling convention.

## Code

Kernel source code is located at `./src`.
- `boot.s` contains the entry point for the kernel. This code does basic initialization and jumps to executing the payload program.
- `kernel.s` contains the kernel code that gets mapped to the high memory. Stuff like scheduling, memory management, and system calls are implemented here.
- `payload.s` contains the userspace program that is first run after initializing the kernel.
- `def.s` contains constant and macro definitions that used in the other kernel source files.

- `dtb.s` contains old device tree parsing code that is not used currently.

The folder `./sloader/` contains a Rust project that might become a proper bootloader for the kernel. For now, the simple code in `boot.s` is used.

## Miscellanious

- The linker script is located at `./link.ld`. 
- The folder `./build` contains build artifacts like object files and the final binary image.
- The file `./todos.md` contains some design questions and issues to fix.
