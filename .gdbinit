set history save on
target extended-remote localhost:3333
symbol-file build/kernel.elf
add-symbol-file build/kernel_virt.elf
layout asm
fs next
