#include "include/const.h"
#include "include/global.h"
#include "include/t_stdio.h"



static int spurious_syscall(void)
{
    t_printf("#!");
    return 0;
}

static int get_ticks(void)
{
    return g_ticks;
}

static char fmt[] = "\r%d.";
static int __declspec(naked) print_int(void)
{
    __asm 
    {
        push    ebx
        lea     eax, [fmt]
        push    eax
        call    t_printf
        add     esp, 8
        xor     eax, eax
        ret
    }
}

void init_syscall(void)
{
    int i = 0;
    for (i = 0; i < nr_syscall; i++)
        g_syscall_table[i] = spurious_syscall;

    g_syscall_table[nr_get_ticks] = get_ticks;
    g_syscall_table[nr_print_int] = print_int;
}