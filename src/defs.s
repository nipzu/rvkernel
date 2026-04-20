########################
# CONSTANT DEFINITIONS #
########################

.equiv EXEC_PAGE_SCHED_NEXT_OFFSET, 0x100
.equiv EXEC_PAGE_VAS_PADDR_OFFSET,  0x118
.equiv EXEC_PAGE_STATUS_OFFSET,     0x200
.equiv EXEC_PAGE_DUMMY_SC_OFFSET,   0x300
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

.equiv SYSCALL_TERMINATE,      1
.equiv SYSCALL_PARK,           2
.equiv SYSCALL_VAS_MAP_FRESH,  8
.equiv SYSCALL_YIELD,         10

.equiv USERSPACE_VADDR_BITS, 38

# TODO: define LOAD_ACQUIRE, STORE_RELEASE, HINT_PAUSE

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
    # reset hart lock memory vars, MCS_LOCKED needs to always be set, 
    # MCS_NEXT technicaly only after unlocking and having a next in queue
    sd zero, EXEC_PAGE_MCS_LOCKED_OFFSET(fp)
    sd t1, EXEC_PAGE_MCS_NEXT_OFFSET(fp)
    # TODO: interrupts?
    amoswap.d.aqrl t2, fp, (t0)             # set queue end to current hart
    beq t1, t2, .L\@_end                    # if the queue was empty, exit
    sd fp, EXEC_PAGE_MCS_NEXT_OFFSET(t2)    # set next of prev to current hart
    .L\@_try_lock:
        # wait for prev to give lock
        # TODO: spin loop hint
        # HINT_PAUSE
        ld t2, EXEC_PAGE_MCS_LOCKED_OFFSET(fp)
        beqz t2, .L\@_try_lock
    # r, w ordering comes from the syntactical control dependency with ld and beqz
    # fence r,r provides ppo ordering for the critical section with the ld in try_lock
    fence r,r
.L\@_end:
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
        bne t2, fp, .L\@_ld_next # cur != last => queue not empty
        sc.d.rl t2, t1, (t0)
        bnez t2, .L\@_cas # cas failed, try again
    # success, exit
    j .L\@_end

    # load next in queue, loop while
    # waiting for next hart to update next ptr
    .L\@_ld_next:
    ld t2, EXEC_PAGE_MCS_NEXT_OFFSET(fp)
    bne t2, t1, .L\@_unlock_next

    .L\@_spin_wait:
        # TODO: HINT_PAUSE
        ld t2, EXEC_PAGE_MCS_NEXT_OFFSET(fp)
        beq t2, t1, .L\@_spin_wait

    .L\@_unlock_next:
    # release store, unlock lock for next
    fence rw, w
    sd t1, EXEC_PAGE_MCS_LOCKED_OFFSET(t2)
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
li a7, 1
1:
srli a0, a1, 63
addi a0, a0, '0'
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

.macro GDB_WAIT_LOOP
    li t0, 1
    bnez t0, .
.endm # GDB_WAIT_LOOP

# TODO: overkill, 64kb
.equiv KERNEL_PAGE_COUNT, 16
.equiv MEM_PAGE_COUNT, 32768 - 512
.equiv PAGE_TABLE_PAGE_COUNT, 63 # = (32768 - 512) / 512
.equiv PREALLOCATED_PAGE_COUNT, KERNEL_PAGE_COUNT + PAGE_TABLE_PAGE_COUNT
#.equiv KERNEL_BASE_VADDR,   0xfffffffffff00000
.equiv KERNEL_BASE_VADDR, 0xffffffd555540000

