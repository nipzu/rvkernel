### Per executor:
 - kernel scratch
 - executor info
 - scheduler entry
 - futex stuff??
 - virtual memory stuff
 - capabilities / handles / resources

### Requirements:
 - rv64ia
 - S-mode
 - rv39?, rv48?

### High Level States:
 - wfi / sleep / program that sleeps???
 - scheduling
 - executing user program
  - handling system call
  - running in U-mode

### System Calls:
 - yield
 - map memory
 - start executor
 - wake
 - stop executor
 - system info: global read-only page
 - terminate

### resources:
 - address space
 - executor
 - are mapped as pages into user vmem with U-mode set
 - address space for executor cannot be changed

### Procedures:
 - virt to phys
 - phys to virt
 - zero page
 - map page(s)

### Userspace pages (lowmem)
 - normal memory (RSW = 0b00) (U=1)
 - device memory (RSW = 0b01) (U=1)
 - executor page (RSW = 0b10) (U=0)
 - vas page      (RSW = 0B11) (U=0)

user mode: sscratch = S satp?, 
supervisor mode: sscratch = 


user mode:
- S-satp
- P-page

kernel mode:
- U-satp
- P-page


- set queue
- park

- read queue
- unpark?

park_and_op
unpark


park_and_op:
1. *thread_page.parked bit = true // still have executing bit set
2. op

unpark:
1. *thread_page.parked bit = false
2. if not executing, move to scheduler queue

scheduler queue can have multiples?

park_and_swap
unpark

park_if(addr, expected):
  if !validate(addr):
    return ERR_ADDR
  set_parked(true)
  v = load_u_virt(addr)
  if v != expected:
    set_parked(false)
    return ERR_VAL
  yield()

unpark(id):
  state = load_state(id)
  if parked(state) && executing(state):

  if parked(state) && !executing(state):

### memory maps
 - reference count in invalid PTE / allocator array node
 - 

### page alloc and scheduling stuff on same page = Global Page

### scheduling 
 - just a global FIFO for now idk
 - thread local spmc?

### page allocation
 - initially support only FLATMEM
 - maybe add support for SPARSEMEM (binary search)
 - see longqueue, mpmc
 - types of kernel pages:
  1. executor
  2. mm (root / other)
  3. hart-local

### kernel register convention
 - x3/gp = global kernel page
 - x4/tp = hart page
 - x8 = current executor
 - x3 = kernel satp
 - x4 = page allocator

### kernel hart page (x4/tp)
 0x000:0x008 = mcs_lock_next
 0x200:0x208 = mcs_lock_held

### global kernel page (x3/gp)
 0x000:0x008 = page_alloc_head
 0x200:0x208 = page_alloc_tail
 0x400:0x408 = sched_mcs_lock
 0x600:0x608 = sched_head
 0x608:0x610 = sched_tail

### executor state page
 0x00:0x08 = pc | kernel hart-local
 0x08:0x10 = x1
 0x10:0x18 = x2
 0x18:0x20 = x3
 0x20:0x28 = x4
 0x28:0x30 = x5
 0x30:0x38 = x6
 0x38:0x40 = x7
 0x40:0x48 = x8
 0x48:0x50 = x9
 0x50:0x58 = x10
 0x58:0x60 = x11
 0x60:0x68 = x12
 0x68:0x70 = x13
 0x70:0x78 = x14
 0x78:0x80 = x15
 0x80:0x88 = x16
 0x88:0x90 = x17
 0x90:0x98 = x18
 0x98:0xA0 = x19
 0xA0:0xA8 = x20
 0xA8:0xB0 = x21
 0xB0:0xB8 = x22
 0xB8:0xC0 = x23
 0xC0:0xC8 = x24
 0xC8:0xD0 = x25
 0xD0:0xD8 = x26
 0xD8:0xE0 = x27
 0xE0:0xE8 = x28
 0xE8:0xF0 = x29
 0xF8:0xF0 = x30
 0xF0:0x100 = x31
 0x100:0x108 = ptr to next to schedule
 0x110:0x118 = satp
 0x118:0x120 = ptr to vas
 0x120:0x128 = current hart page
 0x200:0x208 = state (running / terminated / waiting)
 0x400:0x408 = refcount
 0x800:0x808 = locked
