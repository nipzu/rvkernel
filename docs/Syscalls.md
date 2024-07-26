# System Calls

  

## Calling Convention

### Arguments
- `a0/x10`: system call number
- `a1/x11`: arg1
- `a2/x12`: arg2
- `a3/x13`: arg3

### Return Values
- `a0/x10`: err
- `a1/x11`: res1

## Permissions
- executor_create
- vas_create

## System Call List

### `0x1`: executor_terminate
- does not return
will context switch to user vas

### `0x2`: executor_park
- arg1: timeout (units: ns?)
should timeout be its own call
can this spuriously wake
will not context switch (TODO: timeout)

### `0x3`: executor_unpark(\_many?)
- arg1: handle to executor
may context switch (to kernel?)

### `0x4`: executor_create
- arg1: fresh executor handle
- arg2: vas handle
- arg3: permissions
start in parked state?
will context switch to kernel

### `0x5`: executor_vas_set
- arg1: executor handle
- arg2: new vas handle
will not context switch

### `0x6`: vas_create
- arg1: fresh handle
will context switch to kernel

### `0x7`: vas_destroy
- arg1: vas handle
???

### `0x8`: vas_map_fresh
- arg1: vas handle
- arg2: start address
- arg3: page count
will context switch to kernel

### `0x9`: vas_unmap
- arg1: vas handle
- arg2: start address
- arg3: page count
will context switch to kernel
