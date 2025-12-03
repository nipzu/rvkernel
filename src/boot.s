.include "src/defs.s"

.section .text.boot
.global _start
_start:

# print hartid?
# mv a1, a0
# PRINT_BIN_64

# lla x17, handle_exception
# csrw stvec, x17
# csrr x16, stvec
# bne x16, x17, kernel_panic

csrw sie, zero
csrw sip, zero

lla t0, kernel_panic
csrw stvec, t0

lla s11, _start

li t1, KERNEL_PAGE_COUNT * PAGE_SIZE
add t0, s11, t1

# TODO: check ASID count

# zero out preallocated (kernel text + page table) pages
li t1, PREALLOCATED_PAGE_COUNT
1:
    sd zero, (t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b

# set up rest of the pages for allocation
li t1, MEM_PAGE_COUNT - PREALLOCATED_PAGE_COUNT - 1
addi t0, t0, 8
1:
    sd t0, -8(t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b
sd zero, -8(t0)

# get reserve page for page allocation
li t0, PREALLOCATED_PAGE_COUNT * PAGE_SIZE + PREALLOCATED_PAGE_COUNT * 8
add t1, s11, t0
li t0, PREALLOCATED_PAGE_COUNT * PAGE_SIZE
add t2, s11, t0

# allocate a page
mv t0, t1
sub t0, t0, t2
slli t0, t0, 9
mv t3, s11
add t0, t0, t3
sd zero, (t1)
addi t1, t1, 8

addi s8, t1, -8
mv s9, t0

# t0 now has a fresh page
ZERO_PAGE

# TODO: make these not executable later
# PTE:   DAGUXWRV
li t3, 0b11001111
li t4, 1
slli t4, t4, 28
li t5, 256 # half of ptes

# identity map lower half
1:
    sd t3, (t0)
    addi t0, t0, 8
    add t3, t3, t4
    addi t5, t5, -1
    bnez t5, 1b

# s0 = root table address
addi s0, t0, -2048

mv s4, s0

li s1, KERNEL_BASE_VADDR

# TODO: this assumes sv39

# VPN[2]
srli t3, s1, 30
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t3 a pointer to the first pte
add  t3, t3, s0

# t2 = allocated page
li s10, PAGE_SIZE
add t2, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, t2
ZERO_PAGE

srli t4, t2, 2
ori t4, t4, (1<<5) + 1 # G and V bits
sd t4, (t3)

# VPN[1]
srli t3, s1, 21
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t2 a pointer to the second pte
add t2, t2, t3

# t4 = allocated page
add t4, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, t4
ZERO_PAGE

srli t5, t4, 2
ori t5, t5, (1<<5) + 1 # G and V bits
sd t5, (t2)

# VPN[0]
srli t3, s1, 12
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t3 a pointer to the third pte
add t3, t3, t4

# zero out top 8 bits
mv s1, s11
srli s1, s1, 2
# PTE:        DAGUXWRV
ori s1, s1, 0b11101001
li t2, KERNEL_PAGE_COUNT # TODO: how many pages are needed
1: 
    sd s1, (t3)
    addi s1, s1, 1024
    addi t3, t3, 8
    addi t2, t2, -1
    bnez t2, 1b



# t4 = allocated page
add t4, s9, s10
add s9, s9, s10
addi s8, s8, 8

srli t4, t4, 2
# PTE:        DAGUXWRV
ori s1, t4, 0b11100111 # make the global page RW
sd s1, (t3)

# s0 = to be new satp
srli s0, s0, 12
li t1, 1
slli t1, t1, 63
add s0, s0, t1

# set all asid bits
li t6, 0xffff
slli t6, t6, 44
add s0, s0, t6

# mv a1, s0
# PRINT_BIN_64

csrw satp, s0
sfence.vma


csrr a1, satp
PRINT_BIN_64


li t1, KERNEL_BASE_VADDR
srli t3, t1, 30
andi t3, t3, 0x1ff
slli t3, t3, 3
add  a1, t3, s4
# PRINT_BIN_64

lla a5, foo_test

li a3, KERNEL_BASE_VADDR
add a3, a3, a5
mv a4, s11
sub a3, a3, a4
jr a3

foo_test:

# virtual address
li gp, KERNEL_BASE_VADDR + KERNEL_PAGE_COUNT * PAGE_SIZE

mv a1, gp
PRINT_BIN_64

li t4, 0xaaaaaaaaaaaaaaaa
li s1, 512
1:
    sd t4, (gp)
    addi gp, gp, 8
    addi s1, s1, -1
    bnez s1, 1b

addi gp, gp, -PAGE_SIZE / 2
addi gp, gp, -PAGE_SIZE / 2

mv a1, gp
PRINT_BIN_64

csrr t0, satp
sd t0, GLOBAL_PAGE_KERNEL_SATP_OFFSET(gp)
sd zero, GLOBAL_PAGE_SCHED_MCS_OFFSET(gp)
# TODO: set up rest of gp


# disable execution on direct kernel memory map
slli t0, t0, 20
srli t0, t0, 8

li t1, 256
1:
    ld t2, (t0)
    xori t2, t2, 1 << 3 # X bit
    sd t2, (t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b

sfence.vma


csrr a1, sstatus
srli a1, a1, 32
PRINT_BIN_64


# INIT PROGRAM SETUP
# TODO: should these not be rwx
.equiv INIT_PAYLOAD_LOAD_VADDR, 0x100000
# TODO: hardcoded to be on the same megapage
# .equiv INIT_EXEC_PAGE_VADDR, 0x80000
# TODO: get size from blob
.equiv INIT_PAYLOAD_PAGE_COUNT, 16
.if INIT_PAYLOAD_PAGE_COUNT > 256
.err 
.endif

li s1, INIT_PAYLOAD_LOAD_VADDR

# s0 = allocated page
add s0, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, s0
ZERO_PAGE

# VPN[2]
srli t3, s1, 30
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t3 a pointer to the first pte
add  t3, t3, s0

# copy highmem map
csrr s7, satp
slli s7, s7, 20
srli s7, s7, 8

addi s7, s7, PAGE_SIZE / 4
addi s7, s7, PAGE_SIZE / 4

addi s0, s0, PAGE_SIZE / 4
addi s0, s0, PAGE_SIZE / 4

li s6, 256
1: 
    ld s5, (s7)
    sd s5, (s0)
    addi s0, s0, 8
    addi s7, s7, 8
    addi s6, s6, -1
    bnez s6, 1b

addi s7, s7, -PAGE_SIZE / 2
addi s7, s7, -PAGE_SIZE / 2

addi s0, s0, -PAGE_SIZE / 2
addi s0, s0, -PAGE_SIZE / 2

# t2 = allocated page
li s10, PAGE_SIZE
add t2, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, t2
ZERO_PAGE

srli t4, t2, 2
ori t4, t4, 1 # V bit
sd t4, (t3)

# VPN[1]
srli t3, s1, 21
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t2 a pointer to the second pte
add t2, t2, t3

# t4 = allocated page
add t4, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, t4
ZERO_PAGE

srli t5, t4, 2
ori t5, t5, 1 # V bit
sd t5, (t2)

# VPN[0]
srli t3, s1, 12
andi t3, t3, 0x1ff
slli t3, t3, 3
# make t3 a pointer to the third pte
add t3, t3, t4

# zero out top 8 bits
mv s1, s11
lla t5, init_program_payload_start
add s1, s1, t5
lla t5, _start
sub s1, s1, t5

srli s1, s1, 2
# PTE:        DAGUXWRV
ori s1, s1, 0b11011111
li t2, INIT_PAYLOAD_PAGE_COUNT # TODO: how many pages are needed
1: 
    sd s1, (t3)
    addi s1, s1, 1024
    addi t3, t3, 8
    addi t2, t2, -1
    bnez t2, 1b


# set up executor page at 0x80000
add t3, s9, s10
add s9, s9, s10
addi s8, s8, 8
mv t0, t3
ZERO_PAGE

srli t3, t3, 2
# PTE:        DAGUXWRV
ori t3, t3, 0b11000111
sd t3, 8*128(t4)



srli s7, s0, 2
# TODO: should the vas page be w?
# PTE:        DAGUXWRV
ori s7, s7, 0b11000011
sd s7, 8*129(t4)

# TOOD: check if S-mode page faults are trapped to S or M

# TODO: after all allocations, fixup allocation table
sd zero, (s8)
addi s8, s8, 8
# s8 is now the start of the allocation table

# TODO: senvcfg


# s0 = to be new satp
srli s0, s0, 12
li t1, 1
slli t1, t1, 63
add s0, s0, t1

# keep asid as all zeros
csrw satp, s0
sfence.vma

lla t0, handle_exception
csrw stvec, t0
csrr t1, stvec
bne t0, t1, kernel_panic

li t0, INIT_PAYLOAD_LOAD_VADDR
csrw sepc, t0

li t0, 0x80000
csrw sscratch, t0

sret

# set up kernel mapping:
# identity on lowmem (RWX for now)
# global kernel page (RW) in highmem
# kernel text page(s) (X) in highmem

# csrw sip, x0
# li a0, -1
# csrw sie, a0
# 
# li a1, 2
# csrs sstatus, a1
# 
# # timer
# li a7, 0x54494D45
# li a6, 0
# li a1, 0
# li a0, 20000000
# ecall
# 
# # csrr a1, stvec
# # PRINT_BIN_64
# 
# # auipc a1, 0
# # PRINT_BIN_64
# # csrw sip, x0
# csrr a1, sstatus
# PRINT_BIN_64
# # csrw sip, x0
# # csrr a1, sip
# # PRINT_BIN_64
# 
# j kernel_panic

