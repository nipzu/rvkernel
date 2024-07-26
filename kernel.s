########################
# CONSTANT DEFINITIONS #
########################

.equiv EXEC_PAGE_SCHED_NEXT_OFFSET, 0x100
.equiv EXEC_PAGE_VAS_PADDR_OFFSET,  0x118
.equiv EXEC_PAGE_STATUS_OFFSET,     0x200
.equiv EXEC_PAGE_REFCOUNT_OFFSET,   0x400
.equiv EXEC_PAGE_MCS_NEXT_OFFSET,   0x600
.equiv EXEC_PAGE_MCS_LOCKED_OFFSET, 0x700
.equiv EXEC_TERMINATED, 1

.equiv VAS_REFCOUNT_OFFSET, 0x800
.equiv VAS_REFCOUNT_UNIT, 2

.equiv GLOBAL_PAGE_ALLOC_HEAD_OFFSET,  0x000
.equiv GLOBAL_PAGE_ALLOC_TAIL_OFFSET,  0x200
.equiv GLOBAL_PAGE_SCHED_MCS_OFFSET,   0x400
.equiv GLOBAL_PAGE_SCHED_HEAD_OFFSET,  0x600
.equiv GLOBAL_PAGE_SCHED_TAIL_OFFSET,  0x608
.equiv GLOBAL_PAGE_KERNEL_SATP_OFFSET, 0x700

# .equiv HART_PAGE_MCS_NEXT_OFFSET,   0x000
# .equiv HART_PAGE_MCS_LOCKED_OFFSET, 0x200

# MUST NOT be a multiple of PAGE_SIZE
.equiv MCS_EMPTY, 1

# .equiv SANITY_CHECKS, 1
# use only half because risky
.equiv PAGE_COUNT, 16000
.equiv TEXT_PAGE_ALIGNED_LEN, 4096
.equiv PAGE_TABLE_OFFSET, (4096 * ((PAGE_COUNT + 255) / 256))
.equiv PAGE_SIZE, 4096

.equiv SYSCALL_PARK, 2
.equiv SYSCALL_YIELD, 10

#####################
# MACRO DEFINITIONS #
#####################

# Lock the mcs lock pointed to by t0.
# Not reentrant.
#
# in:
#  t0 = mcs lock address
#  t1 = MCS_EMPTY
# out:
#  t2 = undef
.macro MCS_LOCK
    # TODO: release for zeroing to be visible
    # TODO: interrupts?
    # set queue end to current hart
    amoswap.d t2, fp, (t0)
    # if the queue was empty, exit
    beq t1, t2, .L\@_end
    # set next of prev to current hart
    sd fp, EXEC_PAGE_MCS_NEXT_OFFSET(t2)
    .L\@_try_lock:
        # wait for prev to give lock
        # TODO: spin loop hint
        # pause
        ld t2, EXEC_PAGE_MCS_LOCKED_OFFSET(fp)
        beqz t2, .L\@_try_lock
.L\@_end:
    # acquire fence
    # TODO: can this be relaxed to r,r
    fence r,rw
.endm # MCS_LOCK


# Unlock the mcs lock pointed to by t0
#
# in:
#  t0 = mcs lock address
#  t1 = MCS_EMPTY
# out:
#  t2 = undef
.macro MCS_UNLOCK
    .L\@_cas:
        # try to clear queue if cur is last
        lr.d t2, (t0)
        # cur != last => queue not empty
        bne t2, fp, .L\@_ld_next
        sc.d.rl t2, t1, (t0)
        # cas failed, try again
        bnez t2, .L\@_cas
        # TODO: fence here?
    # success, exit
    j .L\@_end

    .L\@_ld_next:
        # load next in queue, loop while
        # waiting for next hart to update next ptr
        ld t2, EXEC_PAGE_MCS_NEXT_OFFSET(fp)
        beq t2, t1, .L\@_ld_next
    # release store, unlock lock for next
    fence rw, w
    sd t1, EXEC_PAGE_MCS_LOCKED_OFFSET(t2)
    # reset hart lock memory vars
    sd zero, EXEC_PAGE_MCS_LOCKED_OFFSET(fp)
    sd t1, EXEC_PAGE_MCS_NEXT_OFFSET(fp)
.L\@_end:
.endm # MCS_UNLOCK

# Store zero to the PAGE_SIZE bytes pointed to by t0.
# The pointer t0 must aligne to PAGE_SIZE
# 
# in: 
#   t0 = page to zero
# out:
#   t0 unchanged
#   t1 clobbered
.macro ZERO_PAGE
li t1, 64
.L\@_loop:
    sd zero, 0x00(t0)
    sd zero, 0x08(t0)
    sd zero, 0x10(t0)
    sd zero, 0x18(t0)
    sd zero, 0x20(t0)
    sd zero, 0x28(t0)
    sd zero, 0x30(t0)
    sd zero, 0x38(t0)
    addi t0, t0, 0x40
    addi t1, t1, -1
    bnez t1, .L\@_loop
li t1, -PAGE_SIZE
add t0, t0, t1
.endm # ZERO_PAGE

# Free the page pointed to by t0
#
# in:
#  t0 = paddr of page to be freed
#  t1 = start of ram segment
# out:
#
.macro FREE_PAGE
    # TODO: is it safe to have the allocation struct fixed
    # convert raw address to ptr to node in link table
    sub t0, t0, t1
    srli t0, t0, 9
    add t0, t0, t1

    # set next to null and set tail to cur
    sd zero, (t0)
    amoswap.d.rl t1, t0, GLOBAL_PAGE_ALLOC_TAIL_OFFSET(gp)
    sd t0, (t1)
.endm # FREE_PAGE


# decrement the refcount of the page pointed to by t0
#
# in:
#  t0 = page to be freed
#  t1 = start of ram segment
# out:
#
.macro DEC_PAGE_REFCOUNT
    # convert raw address to ptr to node in link table
    sub t0, t0, t1
    srli t0, t0, 9
    add t0, t0, t1

    li t1, -1
    amoadd.d.rl t1, t1, (t0)
    beqz t1, .L\@_end

    fence r, rw

    # set next to null and set tail to cur
    sd zero, (t0)
    amoswap.d.rl t1, t0, GLOBAL_PAGE_ALLOC_TAIL_OFFSET(gp)
    sd t0, (t1)

.L\@_end:
.endm # FREE_PAGE


.macro ALLOC_PAGE

# i guess use this when filling page tables
# TODO; restore reserve first???

# a2 = reserve
# a3 = n
# a4 = out
.L\@_pop:
    li a6, 0
    sd x0, (a2)
    amoswap.d.aqrl t0, a2, GLOBAL_PAGE_ALLOC_TAIL_OFFSET(gp)


.L\@_fst_again:
    ld t1, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
.L\@_snd_again:
    ld t2, (t1)
    beqz t2, .L\@_snd_zero
.L\@_cas:
    lr.d t3, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
    bne t3, t1, .L\@_cas_ne
    sc.d t4, t2, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
    bnez t4, .L\@_cas
    beq a6, a3, .L\@_restore_reserve
    addi a6, a6, 1
    sd t1, (a4)
    addi a4, a4, 8
    mv t1, t2
    j .L\@_snd_again
.L\@_cas_ne:
    mv t1, t3
    j .L\@_snd_again
.L\@_snd_zero:
    bne t0, t1, .L\@_fst_again
.L\@_restore_reserve:
    sd a2, (t0)
    mv a2, t1
    # TODO: wtf is this ret
    ret # a6 contains m

.endm # ALLOC_PAGE


# a2 = reserve
# a3 = n
# a4 = out
.macro ALLOC_SINGLE_PAGE
# TODO; restore reserve first???
	ld	a6, 0(a0)
	sd	zero, 0(a6)
	addi	a2, a1, 8
	amoswap.d.aqrl	a7, a6, (a2)
.L\@_BB4_1:
	ld	a5, 0(a1)
	beq	a5, a7, .L\@_BB4_10
	ld	a2, 0(a5)
	beqz	a2, .L\@_BB4_1
.L\@_BB4_11:
	lr.d	a3, (a1)
	bne	a3, a5, .L\@_BB4_1
	sc.d	a4, a2, (a1)
	bnez	a4, .L\@_BB4_11
	sd	zero, 0(a5)
	sd	a5, 0(a0)
.L\@_BB4_5:
	ld	a2, 0(a1)
	beq	a2, a7, .L\@_BB4_9
	ld	a0, 0(a2)
	beqz	a0, .L\@_BB4_5
.L\@_BB4_14:
	lr.d	a3, (a1)
	bne	a3, a2, .L\@_BB4_5
	sc.d	a4, a0, (a1)
	bnez	a4, .L\@_BB4_14
	mv	a1, a7
.L\@_BB4_9:
	sd	a6, 0(a1)
	mv	a0, a2
	ret
.L\@_BB4_10:
	li	a2, 0
	sd	a5, 0(a0)
	sd	a6, 0(a1)
	mv	a0, a2
	ret


/*
.L\@_pop:
    li a6, 0
    sd x0, (a2)
    amoswap.d.aqrl t0, a2, GLOBAL_PAGE_ALLOC_TAIL_OFFSET(gp)


.L\@_fst_again:
    ld t1, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
.L\@_snd_again:
    ld t2, (t1)
    beqz t2, .L\@_snd_zero
.L\@_cas:
    lr.d t3, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
    bne t3, t1, .L\@_cas_ne
    sc.d t4, t2, GLOBAL_PAGE_ALLOC_HEAD_OFFSET(gp)
    bnez t4, .L\@_cas
    beq a6, a3, .L\@_restore_reserve
    addi a6, a6, 1
    sd t1, (a4)
    addi a4, a4, 8
    mv t1, t2
    j .L\@_snd_again
.L\@_cas_ne:
    mv t1, t3
    j .L\@_snd_again
.L\@_snd_zero:
    bne t0, t1, .L\@_fst_again
.L\@_restore_reserve:
    sd a2, (t0)
    mv a2, t1
    # a6 contains m
*/
.endm # ALLOC_SINGLE_PAGE

# in:
#  t0 = pointer to PTE
#  t1 = start of ram segment
#  t2 = head of freed pages
.macro UNMAP_PTE
    # store PTE PPN mask in t3
    lui  t3, 1048320
    srli t3, t3, 10

    ld a0, (t0)
    sd zero, (t0)

    andi t0, a0, 1
    beqz t0, .L\@_end

    and a0, a0, t3

    slli t0, t0, 2
    sub t0, t0, t1
    srli t0, t0, 9
    add t0, t0, t1

    sd t2, (t0)
    mv t2, t0

.L\@_end:

# .ifdef SANITY_CHECKS
#     # check D,A,G,U bits
#     andi x2, x3, 0b11110000
#     bnez x2, kernel_panic
#     # check bits above PPN
#     srli x2, x3, 53
#     bnez x2, kernel_panic
# .endif

.endm # UNMAP_PTE


.macro TO_KERNEL_SATP 

ld t0, GLOBAL_PAGE_KERNEL_SATP_OFFSET(gp)
csrw satp, t0

.endm # TO_KERNEL_SATP


.macro READ_BE_32
lbu a1, (x1)
lbu x2, 1(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 2(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 3(x1)
slli a1, a1, 8
add a1, a1, x2
.endm

.macro READ_BE_64
lbu a1, (x1)
lbu x2, 1(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 2(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 3(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 4(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 5(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 6(x1)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 7(x1)
slli a1, a1, 8
add a1, a1, x2
.endm

# a1 = number to print, starting from high bit
# x2 = num bits
.macro PRINT_BIN
1:
srli a0, a1, 63
addi a0, a0, '0'
li a7, 1
ecall
slli a1, a1, 1
addi x2, x2, -1
bnez x2, 1b
li a0, 10
ecall
.endm

.macro PRINT_BIN_8
slli a1, a1, 56
li x2, 8
PRINT_BIN
.endm

.macro PRINT_BIN_32
slli a1, a1, 32
li x2, 32
PRINT_BIN
.endm

.macro PRINT_BIN_64
li x2, 64
PRINT_BIN
.endm

.macro PRINT_ASCII
1:
lbu a0, (x1)
beqz a0, 1f
ecall
addi x1, x1, 1
j 1b
1:
.endm


.global _start
_start:

# print hartid?
# mv a1, a0
# PRINT_BIN_64

.equiv DRAM_START, 0x80200000
# TODO: overkill, 64kb
.equiv KERNEL_PAGE_COUNT, 16
.equiv MEM_PAGE_COUNT, 32768 - 512
.equiv PAGE_TABLE_PAGE_COUNT, 63 # = (32768 - 512) / 512
.equiv PREALLOCATED_PAGE_COUNT, KERNEL_PAGE_COUNT + PAGE_TABLE_PAGE_COUNT
#.equiv KERNEL_BASE_VADDR,   0xfffffffffff00000
.equiv KERNEL_BASE_VADDR, 0xffffffcaaaa80000



# lla x17, handle_exception
# csrw stvec, x17
# csrr x16, stvec
# bne x16, x17, kernel_panic

csrw sie, zero
csrw sip, zero

lla t0, _start
li t1, DRAM_START
bne t0, t1, kernel_panic

li t1, KERNEL_PAGE_COUNT * PAGE_SIZE
add t0, t0, t1

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
# li t0, DRAM_START + PREALLOCATED_PAGE_COUNT * PAGE_SIZE
addi t0, t0, 8
1:
    sd t0, -8(t0)
    addi t0, t0, 8
    addi t1, t1, -1
    bnez t1, 1b
sd zero, -8(t0)

# get reserve page for page allocation
li t1, DRAM_START + PREALLOCATED_PAGE_COUNT * PAGE_SIZE + PREALLOCATED_PAGE_COUNT * 8
li t2, DRAM_START + PREALLOCATED_PAGE_COUNT * PAGE_SIZE

# allocate a page
mv t0, t1
sub t0, t0, t2
slli t0, t0, 9
li t3, DRAM_START
add t0, t0, t3
sd zero, (t1)
addi t1, t1, 8

addi s8, t1, -8
mv s9, t0

# t0 now has a fresh page

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
li s1, DRAM_START
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
# mv t0, t4
# ZERO_PAGE

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

csrr a1, satp
# PRINT_BIN_64


li t1, KERNEL_BASE_VADDR
srli t3, t1, 30
andi t3, t3, 0x1ff
slli t3, t3, 3
add  a1, t3, s4
# PRINT_BIN_64


# TODO: after all allocations, fixup allocation table
sd zero, (s8)
addi s8, s8, 8
# s8 is now the start of the allocation table

lla a5, foo_test

li a3, KERNEL_BASE_VADDR
add a3, a3, a5
li a4, DRAM_START
sub a3, a3, a4
jr a3

foo_test:

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


auipc a1, 0
PRINT_BIN_64

j shutdown


# set up kernel mapping:
# identity on lowmem (RWX for now)
# global kernel page (RW) in highmem
# kernel text page(s) (X) in highmem

csrw sip, x0
li a0, -1
csrw sie, a0

li a1, 2
csrs sstatus, a1

li a7, 0x54494D45
li a6, 0
li a1, 0
li a0, 20000000
ecall

# csrr a1, stvec
# PRINT_BIN_64

# auipc a1, 0
# PRINT_BIN_64
# csrw sip, x0
csrr a1, sstatus
PRINT_BIN_64
# csrw sip, x0
# csrr a1, sip
# PRINT_BIN_64

j sleep

boot_start:
j shutdown











.balign PAGE_SIZE
kernel_mem_area_start:


###############
# KERNEL CODE #
###############

mv x27, a1

li x10, 0b0000000000000000000000000000000010000000001000000010000000000000
li x11, 0b00001111
li x13, 1
slli x13, x13, 28
# should index into first PT
sd x11, (x10)
add x11, x11, x13
sd x11, 8(x10)
add x11, x11, x13
sd x11, 16(x10)
add x11, x11, x13
sd x11, 24(x10)
add x11, x11, x13
sd x11, 32(x10)
add x11, x11, x13
sd x11, 40(x10)
add x11, x11, x13
sd x11, 48(x10)
add x11, x11, x13
sd x11, 56(x10)
add x11, x11, x13
sd x11, 64(x10)

srli x10, x10, 12

li x2, 8
slli x2, x2, 60
add x10, x10, x2

li x3, 0b1111111111111111
slli x3, x3, 44
# add x10, x10, x3

sfence.vma
fence.i

csrw satp, x10

sfence.vma
fence.i

addi x27, x27, 72

lbu a1, (x27)
lbu x2, 1(x27)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 2(x27)
slli a1, a1, 8
add a1, a1, x2
lbu x2, 3(x27)
slli a1, a1, 8
add a1, a1, x2

print_bin:

li a3, 64

print_loop:
srli a0, a1, 63
addi a0, a0, '0'
li a7, 1
ecall
slli a1, a1, 1

addi a3, a3, -1
bnez a3, print_loop

j sleep

return_to_user:
csrw sscratch, fp
ld t1, 0x00(fp)
csrw sepc, t1
sd tp,  0x00(fp)
ld x1,  0x08(fp)
ld x2,  0x10(fp)
ld x3,  0x18(fp)
ld x4,  0x20(fp)
ld x5,  0x28(fp)
ld x6,  0x30(fp)
ld x7,  0x38(fp)
# no x8/fp
ld x9,  0x48(fp)
ld x10, 0x50(fp)
ld x11, 0x58(fp)
ld x12, 0x60(fp)
ld x13, 0x68(fp)
ld x14, 0x70(fp)
ld x15, 0x78(fp)
ld x16, 0x80(fp)
ld x17, 0x88(fp)
ld x18, 0x90(fp)
ld x19, 0x98(fp)
ld x20, 0xa0(fp)
ld x21, 0xa8(fp)
ld x22, 0xb0(fp)
ld x23, 0xb8(fp)
ld x24, 0xc0(fp)
ld x25, 0xc8(fp)
ld x26, 0xd0(fp)
ld x27, 0xd8(fp)
ld x28, 0xe0(fp)
ld x29, 0xe8(fp)
ld x30, 0xf0(fp)
ld x31, 0xf8(fp)
ld fp,  0x40(fp)
fence.i
sfence.vma x0, x0
fence iorw, iorw
sret

sleep:
li a0, -1
csrw sie, a0

sleep_loop:
wfi
j sleep_loop

shutdown:
li a7, 0x53525354
li a6, 0
li a0, 0
li a1, 0
ecall

# check if x1 belongs to address space x3

# store PTE PPN mask in x4
lui  x4, 1048320
srli x4, x4, 10

# check that x1 is in user memory
srli x2, x1, 37
bnez x2, fail

# x2 = VPN[2]
srli x2, x1, 29
# x3 = (top PT)[VPN[2]]
slli x2, x2, 3
add  x3, x3, x2
# x3 = top level PTE
ld   x3, (x3)
# check valid bit
andi x2, x3, 1
beqz x2, fail
# check if leaf
andi x2, x3, 0b1110
bnez x2, found_leaf
.ifdef SANITY_CHECKS
    # check D,A,G,U bits
    andi x2, x3, 0b11110000
    bnez x2, kernel_panic
    # check bits above PPN
    srli x2, x3, 53
    bnez x2, kernel_panic
.endif
# extract new PT address from PTE
and x3, x3, x4

# x2 = VPN[1]
srli x2, x1, 20
andi x2, x2, 0b111111111
slli x2, x2, 3
add  x3, x3, x2
ld   x3, (x3)
# check valid bit
andi x2, x3, 1
beqz x2, fail
# check if leaf
andi x2, x3, 0b1110
bnez x2, found_leaf
.ifdef SANITY_CHECKS
    # check D,A,G,U bits
    andi x2, x3, 0b11110000
    bnez x2, kernel_panic
    # check bits above PPN
    srli x2, x3, 53
    bnez x2, kernel_panic
.endif
# extract new PT address from PTE
and  x3, x3, x4

# x2 = VPN[0]
srli x2, x1, 11
andi x2, x2, 0b111111111
slli x2, x2, 3
add  x3, x3, x2
ld   x3, (x3)
# check valid bit
andi x2, x3, 1
beqz x2, fail
.ifdef SANITY_CHECKS
    # check if leaf
    andi x2, x3, 0b1110
    beqz x2, kernel_panic
.endif

found_leaf:
.ifdef SANITY_CHECKS
    # check G,U bits
    andi x2, x3, 0b110000
    # if G,U != 0,1: panic
    xori x2, x2, 0b010000
    bnez x2, kernel_panic
    # check W,R bist
    andi x2, x3, 0b110
    # if W,R == 1,0: panic
    xori x2, x2, 0b100
    beqz x2, kernel_panic
    # check bits above PPN
    srli x2, x3, 53
    bnez x2, kernel_panic
.endif

fail:

kernel_panic:
li a7, 1
li a0, 'P'
ecall
li a0, 'A'
ecall
li a0, 'N'
ecall
li a0, 'I'
ecall
li a0, 'C'
ecall
li a0, '!'
ecall
li a0, 10
ecall
j shutdown

handle_exception:
# TODO: what fences
fence iorw, iorw
sfence.vma x0, x0
fence.i
# sscretch is pointer to executor page
csrrw x1, sscratch, x1
sd x2,  0x10(x1)
sd x3,  0x18(x1)
sd x4,  0x20(x1)
sd x5,  0x28(x1)
sd x6,  0x30(x1)
sd x7,  0x38(x1)
sd x8,  0x40(x1)
sd x9,  0x48(x1)
sd x10, 0x50(x1)
sd x11, 0x58(x1)
sd x12, 0x60(x1)
sd x13, 0x68(x1)
sd x14, 0x70(x1)
sd x15, 0x78(x1)
sd x16, 0x80(x1)
sd x17, 0x88(x1)
sd x18, 0x90(x1)
sd x19, 0x98(x1)
sd x20, 0xa0(x1)
sd x21, 0xa8(x1)
sd x22, 0xb0(x1)
sd x23, 0xb8(x1)
sd x24, 0xc0(x1)
sd x25, 0xc8(x1)
sd x26, 0xd0(x1)
sd x27, 0xd8(x1)
sd x28, 0xe0(x1)
sd x29, 0xe8(x1)
sd x30, 0xf0(x1)
sd x31, 0xf8(x1)
csrr x2, sscratch
sd x2, 0x08(x1)
csrr x2, sepc
sd x2, 0x00(x1)

li a7, 1
li a0, 's'
ecall
li a0, 'y'
ecall
li a0, 's'
ecall
li a0, 'c'
ecall
li a0, 'a'
ecall
li a0, 'l'
ecall
li a0, 'l'
ecall
li a0, 10
ecall
j shutdown


csrr x3, scause
# branch if bit 63 set = interrupt bit
bltz x3, handle_interrupt

# this is an exception
li x4, 8
beq x3, x4, handle_syscall
# this exception is not a system call


executor_terminate:
# mark executor page terminated
li x2, EXEC_TERMINATED
# TODO: fence needed? (or uniquely owned???)
sd x2, EXEC_PAGE_STATUS_OFFSET(x1)

# get vas
ld x2, EXEC_PAGE_VAS_PADDR_OFFSET(x1)

li x3, EXEC_PAGE_REFCOUNT_OFFSET
li x4, -VAS_REFCOUNT_UNIT
amoadd.d.rl x4, x4, (x3)
li x3, VAS_REFCOUNT_UNIT
bne x3, x4, 2f
fence r,rw
# free vas (dec arc)
li x3, VAS_REFCOUNT_OFFSET
add x2, x2, x3
li x3, -2
amoadd.d.rl x3, x2, (x2)
li x3, VAS_REFCOUNT_UNIT
bne x2, x3, 1f
fence r,rw
# free vas page



1:
# free ex page



2:
# nothing to free (anymore)


schedule_next:

addi t0, gp, GLOBAL_PAGE_SCHED_MCS_OFFSET
li t1, MCS_EMPTY
MCS_LOCK

# TODO: queue empty
# pop head
ld fp, GLOBAL_PAGE_SCHED_HEAD_OFFSET(gp)
ld t2,   EXEC_PAGE_SCHED_NEXT_OFFSET(fp)
sd t2, GLOBAL_PAGE_SCHED_HEAD_OFFSET(gp)

MCS_UNLOCK

# TODO: change satp

j return_to_user


handle_syscall:

li x1, SYSCALL_YIELD
beq x1, a0, executor_yield

li x1, SYSCALL_PARK
beq x1, a0, executor_park

j executor_terminate

handle_interrupt:



executor_yield:
# mcs_lock
addi t0, gp, GLOBAL_PAGE_SCHED_MCS_OFFSET
li t1, MCS_EMPTY

MCS_LOCK

# push tail
ld t2, GLOBAL_PAGE_SCHED_TAIL_OFFSET(gp)
beqz t2, 1f # are we the only executor?
sd fp, GLOBAL_PAGE_SCHED_TAIL_OFFSET(gp)
sd fp,   EXEC_PAGE_SCHED_NEXT_OFFSET(t2)

# pop head
ld fp, GLOBAL_PAGE_SCHED_HEAD_OFFSET(gp)
ld t2,   EXEC_PAGE_SCHED_NEXT_OFFSET(fp)
sd t2, GLOBAL_PAGE_SCHED_HEAD_OFFSET(gp)

1:

MCS_UNLOCK

# TODO: change satp
# TODO: set return value

j return_to_user

zero_page:

li x2, 64
1:
sd zero, 0x00(x1)
sd zero, 0x08(x1)
sd zero, 0x10(x1)
sd zero, 0x18(x1)
sd zero, 0x20(x1)
sd zero, 0x28(x1)
sd zero, 0x30(x1)
sd zero, 0x38(x1)
addi x1, x1, 0x40
addi x2, x2, -1
bnez x2, 1b



# a1 = vaddr
# a2 = VAS vaddr
# a3 = perms
executor_create:



executor_park:
.equiv EXEC_NOTIFIED, 2
.equiv EXEC_EMPTY, 1
.equiv EXEC_PARKED, 0

li t0, EXEC_PARKED
li t3, -1
# NOTIFIED => EMPTY || EMPTY => PARKED
addi t2, fp, EXEC_PAGE_STATUS_OFFSET
amoadd.d.aq t0, t3, (t2)
li t1, EXEC_NOTIFIED
# EMPTY => return 
beq t0, t1, return_to_user
j schedule_next
# end executor_park


executor_unpark:

# NOTIFIED => NOTIFIED
# EMPTY => NOTIFIED
# PARKED => EMPTY

# TODO: verify a0
li t0, EXEC_NOTIFIED
addi t2, a0, EXEC_PAGE_STATUS_OFFSET
amoswap.d.rl t0, t0, (t2)
li t1, EXEC_PARKED
bne t0, t1, return_to_user

li t0, EXEC_EMPTY
# TODO: synchronize this
sd t0, EXEC_PAGE_STATUS_OFFSET(a0)

# start executing / add to queue
# TODO: acquire on unparked thread

j return_to_user

# TODO: make sure no deadlock is possible
# 1. lock the current VAS
# 2. check that VAS a2 is in cur VAS
# 3. lock VAS a2?
# 4. 

# end executor_unpark


vas_create:

TO_KERNEL_SATP

ALLOC_SINGLE_PAGE

# assume for now that t0 = new vas_root


# change to kernel satp
# allocate page -> return error if not able
# write default stuff (kernel G mapped)
# lock old vas
# try to traverse old vas and write
# unlock old vas
# change to user satp
# return


vmmap_create:





# map fresh phys pages

# TODO: lock page


# a0 = page root

# TODO: check range





# check that x1 is in user memory
# srli x2, x1, 37
# bnez x2, fail
#
# # x2 = VPN[2]
# srli x2, x1, 29
# # x3 = (top PT)[VPN[2]]
# slli x2, x2, 3
# add  x3, x3, x2
# # x3 = top level PTE
# ld   x3, (x3)
# # check valid bit
# andi x2, x3, 1
# beqz x2, fail
# # check if leaf
# andi x2, x3, 0b1110
# bnez x2, found_leaf
# .ifdef SANITY_CHECKS
#     # check D,A,G,U bits
#     andi x2, x3, 0b11110000
#     bnez x2, kernel_panic
#     # check bits above PPN
#     srli x2, x3, 53
#     bnez x2, kernel_panic
# .endif
# # extract new PT address from PTE
# and x3, x3, x4
#
# # x2 = VPN[1]
# srli x2, x1, 20
# andi x2, x2, 0b111111111
# slli x2, x2, 3
# add  x3, x3, x2
# ld   x3, (x3)
# # check valid bit
# andi x2, x3, 1
# beqz x2, fail
# # check if leaf
# andi x2, x3, 0b1110
# bnez x2, found_leaf
# .ifdef SANITY_CHECKS
#     # check D,A,G,U bits
#     andi x2, x3, 0b11110000
#     bnez x2, kernel_panic
#     # check bits above PPN
#     srli x2, x3, 53
#     bnez x2, kernel_panic
# .endif
# # extract new PT address from PTE
# and  x3, x3, x4
#
# # x2 = VPN[0]
# srli x2, x1, 11
# andi x2, x2, 0b111111111
# slli x2, x2, 3
# add  x3, x3, x2
# ld   x3, (x3)
# # check valid bit
# andi x2, x3, 1
# beqz x2, fail
# .ifdef SANITY_CHECKS
#     # check if leaf
#     andi x2, x3, 0b1110
#     beqz x2, kernel_panic
# .endif
#
# found_leaf:
# .ifdef SANITY_CHECKS
#     # check G,U bits
#     andi x2, x3, 0b110000
#     # if G,U != 0,1: panic
#     xori x2, x2, 0b010000
#     bnez x2, kernel_panic
#     # check W,R bist
#     andi x2, x3, 0b110
#     # if W,R == 1,0: panic
#     xori x2, x2, 0b100
#     beqz x2, kernel_panic
#     # check bits above PPN
#     srli x2, x3, 53
#     bnez x2, kernel_panic
# .endif
#
# fail:

# .balign PAGE_SIZE
# init_program_payload_start:
# j .
