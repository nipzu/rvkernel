 - read fdt to determine usable memory
 - create page allocation structure
 - create kernel global data? ((num of) harts, ptr to scheduling & allocation)
  - maybe just use registers
 - create scheduling structure
 - create memory map structures
 - init program setup (create descriptor, insert to scheduler, memory map)
 - create per-thread descriptors
 - set trap handlers
 - wake up all threads


sloader:
 - read fdt
 - set up memory allocation (needs fdt)
 - set up scheduling?
 - set up global page
 - set up hart pages
 - set up exception and interrupt handling (needs fdt)
 - set up uloader device map from fdt (without kernel)
 - set up uloader exe and stack memory by mapping (?)

 (hacky) act as a user prgoram and perform syscalls to set up uloader program
 (hacky) "become" uloader
  - jump to kernel code that returns to executor?
