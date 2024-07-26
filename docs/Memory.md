# Memory Page Types

### Kernel (highmem)
- Kernel Global Page
- Hart Page
- Identity map Page Table? / Memory allocation table?

### User (lowmem)
- Normal user page
- Page Table pages (vmemspace VMS objects)
- Executor pages (executor objects) 

# Memory Mapping

### Boot
1. Create map table
2. Create kernel map
Global:
- kernel code: RXG
- kernel scratch: RWG
- HART page: RWG

### Page alloc table
- 8 bytes per page
- if allocated, `2 * refcount + 1`
- if not, pointer to next element of alloc queue (ptr to elem, not index) (always even)
- 

Have linked list of executors for VAS?

- A memory operation succeeding the unmapping in global program order can either
  1. cause a page fault
  2. execute as if the unmapping had not happened

- A memory operation preceding 


- A memory operation M is said to precede a system call S modifying the same VAS if:
  - M precedes S in program order, or
  - M is a store to address x and there is a load L from address x such that: M precedes L in global program order, and L precedes S

- M precedes mmap => old mapping
- M succeeds mmap => new mapping
- M overlaps mmap => either old or new mapping (separately for each M?)

- M precedes munmap => old mapping
- M succeeds munmap => page fault
- M overlaps munmap => old mapping or page fault

TODO: racy mmap & mmap (some global order?, maybe not for nonoverlapping)
TODO: racy mmap & munmap (some global order?)
 
### Unmap (in progress)

- Unmap all in range (allow holes)
- Just run unmap(0, MAX) on termination
- Have to be careful with use after free
- probably check whole pages for empty when deleting parents?



v0:
1. lock the VAS
2. unmap to a separate linked list
3. sfence.vma on all harts
4. append freed to alloc list
5. unlock the VAS


Generation counter for VAS?
- executor has counter
- if overflow remove/panic


### Unmap
- 
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

- vas page (RSW = 0B11) (U=0)



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

  