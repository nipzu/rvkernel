_PAGE_SIZE = 4096;
_KERNEL_TEXT_BASE = 0x80200000;

SECTIONS {
    . = _KERNEL_TEXT_BASE;
    .text : {
        KEEP(*(.text.boot))
        *(.text)
        *(.text.*)
    }

    .rodata : /* TODO: make sure this section is empty */
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

    /DISCARD/ : { *(.comment) }
}

ASSERT(_KERNEL_TEXT_BASE % _PAGE_SIZE == 0,
"kernel base not aligned to the size of a page");
ASSERT(SIZEOF(.got) == 0,
"non-empty global object table");
/* TODO: does this even work? */
ASSERT(SIZEOF(COMMON) == 0, "COMMON not empty");
