# TODOS
 - P without VS, extra state
 - should Smstateen be mandatory
 - fdt memory reservation block vs reserved-memory node
 - store conditional on context switch / clear reservation set
 - kernel mapping of mm/ex pages? separate address space for kernel (identity map)
 - how to map page address -> refcount/alloc struct
 - move mcs_lock state from hart to executor (remove hart page completely?)
 - dram should be in lowest 38 bits of physaddr
