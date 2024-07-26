.section .text.boot
_start:

bnez a0, 1f
lla sp, _stack_end

# TODO: zero bss?
j sloader_main

.balign 4096
_stack_start:
.space 8*4096
_stack_end:
