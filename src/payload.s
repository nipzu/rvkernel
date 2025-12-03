.include "src/defs.s"

.section .text.payload

.global init_program_payload_start
init_program_payload_start:


li x1, 1
li x2, 2
li x3, 3
li x4, 4
li x5, 5
li x6, 6
li x7, 7
li x8, 8
li x9, 9
#li x10, 10
#li x11, 11
li x12, 12
li x13, 13
li x14, 14
li x15, 15
li x16, 16
li x17, 17
li x18, 18
li x19, 19
li x20, 20
li x21, 21
li x22, 22
li x23, 23
li x24, 24
li x25, 25
li x26, 26
li x27, 27
li x28, 28
li x29, 29
li x30, 30
li x31, 31

ecall

li a0, 1
bne a0, x1, 2f
li a0, 2
bne a0, x2, 2f
li a0, 3
bne a0, x3, 2f
li a0, 4
bne a0, x4, 2f
li a0, 5
bne a0, x5, 2f
li a0, 6
bne a0, x6, 2f
li a0, 7
bne a0, x7, 2f
li a0, 8
bne a0, x8, 2f
li a0, 9
bne a0, x9, 2f
# li a0, 10
# bne a0, x10, 2f
# li a0, 11
# bne a0, x11, 2f
li a0, 12
bne a0, x12, 2f
li a0, 13
bne a0, x13, 2f
li a0, 14
bne a0, x14, 2f
li a0, 15
bne a0, x15, 2f
li a0, 16
bne a0, x16, 2f
li a0, 17
bne a0, x17, 2f
li a0, 18
bne a0, x18, 2f
li a0, 19
bne a0, x19, 2f
li a0, 20
bne a0, x20, 2f
li a0, 21
bne a0, x21, 2f
li a0, 22
bne a0, x22, 2f
li a0, 23
bne a0, x23, 2f
li a0, 24
bne a0, x24, 2f
li a0, 25
bne a0, x25, 2f
li a0, 26
bne a0, x26, 2f
li a0, 27
bne a0, x27, 2f
li a0, 28
bne a0, x28, 2f
li a0, 29
bne a0, x29, 2f
li a0, 30
bne a0, x30, 2f
li a0, 31
bne a0, x31, 2f

1:
j 3f

2:
li a0, 1
ecall
j .

3:

# vas map fresh
li a0, 8
li a1, 129 * PAGE_SIZE
li a2, 0x3fffc00000
li a3, 512
ecall


li a0, 1
ecall
