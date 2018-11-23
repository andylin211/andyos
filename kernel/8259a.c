#include "include/const.h"
#include "include/basic.h"
#include "include/t_stdio.h"
#include "include/global.h"

/*
* 8259a master port is 20h and 21h
*         slave port is a0h and a1h
* 
* icw: initialization control word
* ocw: operation control word
*/

/*
* icw1 (20h or a0h)
* icw1{0} = 1 (need icw4)
* icw1{1} = 0 (slave 8259a)
* icw1{2} = 0 (8 byte interrupt vector)
* icw1{3} = 0 (edge triggered mode)
* icw1{4} = 1 (must 1)
* icw1{7..5} = 0 (must 0)
*    eg: out_byte(0x20, 0x11);
* 
* icw2 (21h or a1h)
* icw2{2..0}    = 0 (80x86 arch)
* icw2{7..3}    = 0x20 (irq0 start from 0x20)
*    eg: out_byte(0x21, 0x20);
* 
* icw3 (21h, master)
* icw3    = 00000100b (irq2 connects to slave)
*     eg: out_byte(0x21, 0x04);
*
* icw3 (a1h, slave)
* icw3{2..0}    = 0x2 (slave's irq2 connects to master)
* icw3{7..3}    = 0
* 
* icw4 (21h or a1h)
* icw4{0}        = 1 (80x86 mode)
* icw4{1}     = 0 (normal eoi)
* icw4{3..2}    = 0 (buffer mode)
* icw4{4}        = 0 (sequence mode)
* icw4{7..5}    = 0 (not used)
*     eg: out_byte(0x21, 0x01); 
*
* ocw1 (21h, a1h)
* ocw1{7..0}    = 11111110b (1 for disable)
*     eg: out_byte(0x21, 0xfe) //enable clock only
*
* ocw2 (20h, a0h)
* ocw2{5}        = 1 (send end of interrupt to device!)
*     eg: out_byte(0x20, 0x20)
*/

void spurious_irq(u32_t irq)
{
    t_printf("!%d", irq);
}

void init_8259a(void)
{
    int i = 0;
    for (i = 0; i < nr_irq; i++)
        g_irq_table[i] = spurious_irq;

    out_byte(int_m_ctl, 0x11); 
    out_byte(int_s_ctl, 0x11);        // basic 

    out_byte(int_m_ctlmask, 0x20);     // irq0 is 0x20
    out_byte(int_s_ctlmask, 0x28);     // irq0 is 0x28
    
    out_byte(int_m_ctlmask, 0x04); 
    out_byte(int_s_ctlmask, 0x02);     // connect point

    out_byte(int_m_ctlmask, 0x01); 
    out_byte(int_s_ctlmask, 0x01);  // icw4

    out_byte(int_m_ctlmask, 0xff);    
    out_byte(int_s_ctlmask, 0xff);     // disable all
}

void __declspec(naked) disable_irq(u32_t irq)
{
    __asm 
    {
        mov     ecx, [esp + 4]         // cl = irq
        pushf
        cli
        mov     ah, 1
        rol     ah, cl
        cmp     cl, 8
        jae     disable_8             

    disable_0:                        // if irq < 8
        in         al, int_m_ctlmask
        or          al, ah
        out     int_m_ctlmask, al
        popf 
        ret 

    disable_8:                         // if irq >= 8
        in      al, int_s_ctlmask
        or         al, ah
        out     int_s_ctlmask, al
        popf
        ret
    }
}

void __declspec(naked) enable_irq(u32_t irq)
{
    __asm 
    {
        mov     ecx, [esp + 4]        // cl = irq
        pushf
        cli
        mov     ah, ~1
        rol     ah, cl                    
        cmp     cl, 8
        jae     enable_8
    
    enable_0:                         // if irq < 8
        in         al, int_m_ctlmask
        and     al, ah
        out     int_m_ctlmask, al
        popf
        ret

    enable_8:                         // if irq >= 8 
        in         al, int_s_ctlmask
        and     al, ah
        out     int_s_ctlmask, al
        popf
        ret
    }
}

void put_irq_handler(int irq, void* handler)
{
    disable_irq(irq);
    g_irq_table[irq] = handler;
}