#include "include/const.h"
#include "include/global.h"
#include "include/basic.h"
#include "include/8259a.h"
#include "include/t_stdio.h"

static void keyboard_handler()
{    
    u8_t code = in_byte(kb_rw_buf);
    if (code < 0x80 && g_keymap[code * 3])
        t_printf("%c", g_keymap[code * 3]);
    /*
    if (g_kb_in.count < kb_buf_len) 
    {
        *(g_kb_in.head) = code;
        g_kb_in.head++;
        if (g_kb_in.head == g_kb_in.buf + kb_buf_len)
        {
            g_kb_in.head = g_kb_in.buf;
        }
        g_kb_in.count++;
    }*/
}

void init_keyboard(void)
{
    g_kb_in.count = 0;
    g_kb_in.head = g_kb_in.tail = g_kb_in.buf;

    put_irq_handler(irq_keyboard, keyboard_handler);
    enable_irq(irq_keyboard);
}
