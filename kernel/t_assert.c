#include "include/t_assert.h"
#include "include/t_stdio.h"

void t_assert_func(char* file, int line)
{
    t_printf("assert fail! function: %s, line: %d\r\n", file, line);
    __asm jmp $
}
