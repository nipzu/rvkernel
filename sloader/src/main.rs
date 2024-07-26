#![feature(decl_macro)]
#![feature(iter_array_chunks)]
#![feature(pointer_is_aligned_to)]
#![no_std]
#![no_main]

use core::arch::{asm, global_asm};
use core::fmt::Write;

global_asm!(include_str!("start.S"));

#[no_mangle]
pub extern "C" fn sloader_main(hart_id: usize, fdt: *mut u8) -> ! {
    // assert we are in S-mode
    // check ASIDLEN

    // create main memory allocator

    // create memory map for kernel

    write!(DebugConsole, "test").unwrap();
    debug_putstr("Hello world!");

    unsafe {
        write!(DebugConsole, "test").unwrap();
        write!(DebugConsole, "{:x}", hart_id).unwrap();
        let header = FDTHeader::from_bytes(&*(fdt as *const [u8; 40]));
        write!(DebugConsole, "{:x}", header.magic).unwrap();
        header.print_tree(fdt);
        debug_putstr("Hello world!");
    }

    // map fdt

    // wake other threads
    sleep()
}

struct DebugConsole;
impl Write for DebugConsole {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        debug_putstr(s);
        Ok(())
    }
}

fn debug_putstr(s: &str) {
    for c in s.chars() {
        debug_putchar(c);
    }
}

fn debug_putchar(c: char) {
    let x = c as u32 as u64;
    unsafe {
        asm!("li a7, 1", "ecall", in("a0") x, options(nomem));
    }
}

#[panic_handler]
fn panic_abort(_info: &core::panic::PanicInfo) -> ! {
    sleep()
}

fn sleep() -> ! {
    loop {
        unsafe {
            asm!("wfi", options(nomem));
        }
    }
}

use core::ffi::CStr;

#[derive(Debug)]
pub struct FDTHeader {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    _boot_cpuid_phys: u32,
    _size_dt_strings: u32,
    _size_dt_struct: u32,
}

fn u32_from_be_bytes(index: usize, buffer: &[u8; 40]) -> u32 {
    u32::from_be_bytes(buffer[4 * index..4 * index + 4].try_into().unwrap())
}

impl FDTHeader {
    pub fn from_bytes(bytes: &[u8; 40]) -> Self {
        // let u32s = bytes.iter().copied().array_chunks::<4>().map(u32::from_be_bytes);

        let this = Self {
            magic: u32_from_be_bytes(0, bytes),
            totalsize: u32_from_be_bytes(1, bytes),
            off_dt_struct: u32_from_be_bytes(2, bytes),
            off_dt_strings: u32_from_be_bytes(3, bytes),
            off_mem_rsvmap: u32_from_be_bytes(4, bytes),
            version: u32_from_be_bytes(5, bytes),
            last_comp_version: u32_from_be_bytes(6, bytes),
            _boot_cpuid_phys: u32_from_be_bytes(7, bytes),
            _size_dt_strings: u32_from_be_bytes(8, bytes),
            _size_dt_struct: u32_from_be_bytes(9, bytes),
        };


        assert_eq!(this.magic, 0xd00dfeed);
        assert!(this.off_dt_strings < this.totalsize);
        assert!(this.off_dt_struct < this.totalsize);
        assert!(this.off_mem_rsvmap < this.totalsize);
        assert!(this.version >= 16);
        assert_eq!(this.last_comp_version, 16);

        this
    }

    pub unsafe fn reservations(&self, dtb: *const u8) -> impl Iterator<Item = (u64, u64)> {
        let base = dtb.add(self.off_mem_rsvmap as usize);
        (0..).map_while(move |i| {
            let address = u64::from_be_bytes(*base.add(16 * i).cast::<[u8; 8]>());
            let size = u64::from_be_bytes(*base.add(16 * i + 8).cast::<[u8; 8]>());
            (address != 0 || size != 0).then_some((address, size))
        })
    }

    pub unsafe fn print_tree(&self, base: *const u8) {
        let mut ptr = base.add(self.off_dt_struct as usize);
        let mut indent = 0;
        loop {
            assert!(ptr.is_aligned_to(4));
            match u32::from_be_bytes(ptr.cast::<[u8; 4]>().read()) {
                0x00000001 => {
                    for _ in 0..indent {
                        debug_putstr(" ");
                    }
                    let name = CStr::from_ptr(ptr.add(4).cast());
                    debug_putstr(name.to_str().unwrap_or("not utf-8"));
                    debug_putstr(": {\n");
                    if name.to_bytes().windows(3).any(|w| w == b"rng")
                        && !name.to_bytes().starts_with(b"rng@")
                    {
                        return;
                    }
                    indent += 1;
                    ptr = ptr.add(4 + name.to_bytes_with_nul().len());
                    ptr = ptr.add(ptr.align_offset(4));
                }
                0x00000002 => {
                    indent -= 1;
                    for _ in 0..indent {
                        debug_putstr(" ");
                    }
                    debug_putstr("}\n");
                    ptr = ptr.add(4);
                }
                0x00000003 => {
                    for _ in 0..indent {
                        debug_putstr(" ");
                    }
                    let len = u32::from_be_bytes(ptr.add(4).cast::<[u8; 4]>().read());
                    let nameoff = u32::from_be_bytes(ptr.add(8).cast::<[u8; 4]>().read());
                    let name = CStr::from_ptr(
                        base.add(self.off_dt_strings as usize)
                            .add(nameoff as usize)
                            .cast(),
                    );
                    debug_putstr(name.to_str().unwrap_or("not utf-8"));
                    debug_putstr("\n");
                    if name.to_bytes() == b"compatible" {
                        //println!("{len}");
                        //println!("{:?}", CStr::from_ptr(ptr.add(12).cast()));
                        debug_putstr("\n")
                    }
                    ptr = ptr.add(12 + len as usize);
                    ptr = ptr.add(ptr.align_offset(4));
                }
                0x00000004 => {
                    for _ in 0..indent {
                        debug_putstr(" ");
                    }
                    debug_putstr("NOP Token\n");
                    ptr = ptr.add(4);
                }
                0x00000009 => {
                    assert_eq!(indent, 0);
                    return;
                }
                _ => panic!("unknown token"),
            }
        }
    }
}

#[repr(u32)]
pub enum FDTToken {
    BeginNode = 0x00000001,
    EndNode = 0x00000002,
    Prop = 0x00000003,
    Nop = 0x00000004,
    End = 0x00000009,
}
