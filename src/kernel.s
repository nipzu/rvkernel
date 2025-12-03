.include "src/defs.s"

.section .text.kernel
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

# loads all registers other than a0 and a1
return_to_user:

# dummy sc store
addi t0, tp, EXEC_PAGE_DUMMY_SC_OFFSET
sc.d t0, t0, (t0)

# set return address
ld t0, 0x00(tp)
# TODO: when to do this?
addi t0, t0, 4
csrw sepc, t0

ld x1,  0x08(tp)
ld x2,  0x10(tp)
ld x3,  0x18(tp)
#  x4 = tp
ld x5,  0x28(tp)
ld x6,  0x30(tp)
ld x7,  0x38(tp)
ld x8,  0x40(tp)
ld x9,  0x48(tp)
#  x10 = a0
#  x11 = a1
ld x12, 0x60(tp)
ld x13, 0x68(tp)
ld x14, 0x70(tp)
ld x15, 0x78(tp)
ld x16, 0x80(tp)
ld x17, 0x88(tp)
ld x18, 0x90(tp)
ld x19, 0x98(tp)
ld x20, 0xa0(tp)
ld x21, 0xa8(tp)
ld x22, 0xb0(tp)
ld x23, 0xb8(tp)
ld x24, 0xc0(tp)
ld x25, 0xc8(tp)
ld x26, 0xd0(tp)
ld x27, 0xd8(tp)
ld x28, 0xe0(tp)
ld x29, 0xe8(tp)
ld x30, 0xf0(tp)
ld x31, 0xf8(tp)

# finally, load tp
ld tp,  0x20(tp)

# TODO: what fences
# fence.i
# sfence.vma
# fence iorw, iorw
fence rw, rw
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

# mv a1, a0
# PRINT_BIN_64

j shutdown

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

.global handle_exception
handle_exception:

# TODO: need fences?
# fence iorw, iorw
# sfence.vma x0, x0
# fence.i

# sscretch is pointer to executor page
csrrw tp, sscratch, tp
sd x1,  0x08(tp)
sd x2,  0x10(tp)
sd x3,  0x18(tp)
# don't store the tp
sd x5,  0x28(tp)
sd x6,  0x30(tp)
sd x7,  0x38(tp)
sd x8,  0x40(tp)
sd x9,  0x48(tp)
sd x10, 0x50(tp)
sd x11, 0x58(tp)
sd x12, 0x60(tp)
sd x13, 0x68(tp)
sd x14, 0x70(tp)
sd x15, 0x78(tp)
sd x16, 0x80(tp)
sd x17, 0x88(tp)
sd x18, 0x90(tp)
sd x19, 0x98(tp)
sd x20, 0xa0(tp)
sd x21, 0xa8(tp)
sd x22, 0xb0(tp)
sd x23, 0xb8(tp)
sd x24, 0xc0(tp)
sd x25, 0xc8(tp)
sd x26, 0xd0(tp)
sd x27, 0xd8(tp)
sd x28, 0xe0(tp)
sd x29, 0xe8(tp)
sd x30, 0xf0(tp)
sd x31, 0xf8(tp)

csrrw t0, sscratch, tp
sd t0, 0x20(tp)
csrr t0, sepc
sd t0, 0x00(tp)

li a7, 1
li a0, 'e'
ecall
li a0, 'x'
ecall
li a0, 'c'
ecall
li a0, 'e'
ecall
li a0, 'p'
ecall
li a0, 't'
ecall
li a0, 'i'
ecall
li a0, 'o'
ecall
li a0, 'n'
ecall
li a0, 10
ecall

li a7, 1
li a0, 's'
ecall
li a0, 'c'
ecall
li a0, 'a'
ecall
li a0, 'u'
ecall
li a0, 's'
ecall
li a0, 'e'
ecall
li a0, ':'
ecall
li a0, ' '
ecall
csrr a1, scause
PRINT_BIN_64

li a7, 1
li a0, 's'
ecall
li a0, 't'
ecall
li a0, 'v'
ecall
li a0, 'a'
ecall
li a0, 'l'
ecall
li a0, ':'
ecall
li a0, ' '
ecall
li a0, ' '
ecall
csrr a1, stval
PRINT_BIN_64

li a7, 1
li a0, 's'
ecall
li a0, 'e'
ecall
li a0, 'p'
ecall
li a0, 'c'
ecall
li a0, ':'
ecall
li a0, ' '
ecall
li a0, ' '
ecall
li a0, ' '
ecall
csrr a1, sepc
PRINT_BIN_64

# sret
# j shutdown

csrr t0, scause
# branch if bit 63 set = interrupt bit
bltz t0, handle_interrupt

# this is an exception
li t1, 8
beq t0, t1, handle_syscall

# this exception is not a system call
# terminate the running executor

executor_terminate:
j shutdown
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

# TODO: maybe keep in register
ld a0, 0x50(tp)

li t0, SYSCALL_YIELD
beq t0, a0, executor_yield

li t0, SYSCALL_PARK
beq t0, a0, executor_park

li t0, SYSCALL_VAS_MAP_FRESH
beq t0, a0, vas_map_fresh

# TODO: should be the default fallthrough
li t0, SYSCALL_TERMINATE
beq t0, a0, executor_terminate

# TODO: if ecall
# csrr t0, sepc
# addi t0, t0, 4
# csrw sepc, t0
# ld t0, (tp)
# addi t0, t0, 4
# sd t0, (tp)

j return_to_user


j executor_terminate

handle_interrupt:

li a7, 1
li a0, 'i'
ecall
li a0, 'n'
ecall
li a0, 't'
ecall
li a0, 'e'
ecall
li a0, 'r'
ecall
li a0, 'r'
ecall
li a0, 'u'
ecall
li a0, 'p'
ecall
li a0, 't'
ecall
li a0, 10
ecall

j shutdown



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


vas_map_fresh:

li a7, 1
li a0, 'v'
ecall
li a0, 'a'
ecall
li a0, 's'
ecall
li a0, 10
ecall

ld a1, 0x58(tp)

# check that the vas pointer is aligned
slli t0, a1, 64 - 12
bnez t0, executor_terminate

# check that the vas pointer is in userspace
srli t0, a1, USERSPACE_VADDR_BITS
bnez t0, executor_terminate

# check that the passed vas pointer is mapped
# and has the U-bit set
addi t1, a1, PAGE_SIZE / 4
lla t0, vas_pointer_invalid
csrrw t0, stvec, t0

ld t1, (PAGE_SIZE / 4)(t1)
csrw stvec, t0

# lock vas
# check range
# check available memory
# get pages
# zero pages (using direct mapping)
# unlock vas


j return_to_user

.balign 4
vas_pointer_invalid:
csrw stvec, t0
j executor_terminate




.global kernel_panic
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
