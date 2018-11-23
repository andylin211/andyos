#include "include/type.h"

void out_byte(u16_t port, u8_t val)
{
    __asm
    {
        mov     al, [val]
        mov     dx, [port]
        out     dx, al
        nop
        nop
    }
}

char in_byte(u16_t port)
{
    __asm 
    {
        xor     eax, eax
        mov     dx, [port]
        in      al, dx
        nop
        nop
    }
}

void set_descriptor(descriptor_t* desc, u32_t base, u32_t limit, u16_t attr)
{
    desc->base_low = base & 0xffff;
    desc->limit_low    = limit & 0xffff;
    desc->base_mid = (base >> 16) & 0xff;
    desc->attr1 = attr & 0xff;
    desc->limit_high_attr2 = ((limit >> 16) & 0xf) | ((attr >> 8) & 0xf0);
    desc->base_high = (base >> 24) & 0xff;
}

void set_gate(gate_t* gate, u32_t entry, u16_t attr)
{
    gate->attr = attr;
    gate->entry_low = entry & 0xffff;
    gate->entry_high = (entry >> 16) & 0xffff;
    gate->selector = ring0_code_selector;
}