#include "include/global.h"
#include "include/t_stdio.h"

int get_ticks(void)
{
    __asm
    {
        mov     eax, nr_get_ticks
        int     0x80
    }
}

int print_int(int i)
{
    __asm
    {
        mov     ebx, [i]
        mov     eax, nr_print_int
        int     0x80
    }
}