_PAGE_SIZE = 4096;
_DRAM_START = 0x80200000;

SECTIONS {
    . = _DRAM_START;
    .text : {
        *(.text.boot)
        . = ALIGN(_PAGE_SIZE);
        *(.text.kernel)
        . = ALIGN(_PAGE_SIZE);
        *(.text.payload)

        /* *(.text) */
        /* *(.text.*) */
    }

    /* .rodata :  TODO: make sure this section is empty */
/*
    { *(.rodata) *(.rodata.*) }

    . = ALIGN(_PAGE_SIZE);

    .data :
    { *(.data) *(.data.*) }

    .bss (NOLOAD) : {
        . = ALIGN(64);
        _bss_start = .;
        *(.bss) *(.bss.*)
        *(COMMON)
        . = ALIGN(_PAGE_SIZE);
        _bss_end = .;
    }
*/

    /DISCARD/ : { *(.comment) }
}
