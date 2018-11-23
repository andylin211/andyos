#include "include/const.h"
#include "include/global.h"
#include "include/basic.h"
#include "include/8259a.h"
#include "include/t_stdio.h"

static void keyboard_handler()
{    
    u8_t i = in_byte(kb_rw_buf);
    t_printf("0x%x", i);
    if (kb_in.count < kb_buf_len) 
    {
        *(kb_in.head) = i;
        kb_in.head++;
        if (kb_in.head == kb_in.buf + kb_buf_len) 
        {
            kb_in.head = kb_in.buf;
        }
        kb_in.count++;
    }
}

void init_keyboard(void)
{

    put_irq_handler(irq_keyboard, keyboard_handler);
    enable_irq(irq_keyboard);
}
