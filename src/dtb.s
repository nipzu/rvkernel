

print_dtb:

###############
# DTB PARSING #
###############


#la a1, _start
#PRINT_BIN_64
#j shutdown


# assume x1 is *dtb
mv x1, a1
mv x21, a1
PRINT_BIN_64
li a7, 1

# put magic into a1
li a0, 'm'
ecall
li a0, ' '
ecall
READ_BE_32
li x22, 0xd00dfeed
bne a1, x22, fail
PRINT_BIN_32
addi x1, x1, 4

# a1 = totalsize
li a0, 't'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# a1 = off_dt_struct
li a0, 'S'
ecall
li a0, ' '
ecall
READ_BE_32
mv x22, a1
PRINT_BIN_32
addi x1, x1, 4

# a1 = off_dt_strings
li a0, 's'
ecall
li a0, ' '
ecall
READ_BE_32
mv x23, a1
PRINT_BIN_32
addi x1, x1, 4

# a1 = off_mem_rsvmap
li a0, 'r'
ecall
li a0, ' '
ecall
READ_BE_32
mv x24, a1
PRINT_BIN_32
addi x1, x1, 4

# a1 = version
li a0, 'v'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# a1 = last_comp_version
li a0, 'c'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# a1 = boot_cpuid_phys
li a0, 'i'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# a1 = size_dt_strings
li a0, 'l'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# a1 = size_dt_struct
li a0, 'L'
ecall
li a0, ' '
ecall
READ_BE_32
PRINT_BIN_32
addi x1, x1, 4

# x21 = *header
# x22 = off_dt_struct
# x23 = off_dt_strings
# x24 = off_mem_rsvmap

li a0, 'r'
ecall
li a0, 's'
ecall
li a0, 'v'
ecall
li a0, 10
ecall

add x1, x21, x24

print_rsv:

READ_BE_64
mv x25, a1
READ_BE_64
or x26, x25, a1
beqz x26, rsv_end

mv x26, a1
mv a1, x25
PRINT_BIN_64
li a0, ':'
ecall
mv a1, x25
PRINT_BIN_64
addi x1, x1, 16
j print_rsv

rsv_end:


li a0, 's'
ecall
li a0, 't'
ecall
li a0, 'r'
ecall
li a0, 'u'
ecall
li a0, 'c'
ecall
li a0, 't'
ecall
li a0, 10
ecall

add x1, x21, x22

fdt_parse:

READ_BE_32

li x25, 0x1
beq a1, x25, begin_node

li x25, 0x2
beq a1, x25, end_node

li x25, 0x3
beq a1, x25, prop

li x25, 0x4
beq a1, x25, fdt_nop

li x25, 0x9
beq a1, x25, fdt_end

j kernel_panic

begin_node:
addi x1, x1, 4
PRINT_ASCII
li a0, '{'
ecall
li a0, 10
ecall
addi x1, x1, 1
neg x25, x1
andi x25, x25, 3
add x1, x1, x25
j fdt_parse


prop:
addi x1, x1, 4
READ_BE_32
mv x25, a1
addi x1, x1, 4
READ_BE_32
mv x26, x1
add x1, x21, x23
add x1, x1, a1
PRINT_ASCII
mv x1, x26
li a0, 10
ecall
addi x1, x1, 4
beqz x25, prop_loop_end
prop_loop:
lbu a1, (x1)
addi x1, x1, 1
PRINT_BIN_8
addi x25, x25, -1
bnez x25, prop_loop
prop_loop_end:
neg x25, x1
andi x25, x25, 3
add x1, x1, x25
j fdt_parse

end_node:
li a0, '}'
ecall
li a0, 10
ecall
fdt_nop:
addi x1, x1, 4
j fdt_parse


fdt_end:

j boot_start
