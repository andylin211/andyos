#include "include/type.h"
#include "include/screen.h"
#include "include/t_string.h"
#include "include/t_stdlib.h"

static void print_string(char* str)
{
    while (*str)
    {
        print_char(*str);
        str++;
    }
}

/*
* %c - char 
* %s - string
* %x - digit to 0000abcd
* %d - digit to 413
*/
void t_printf(char* format, ...)
{    
    int special = 0;
    static char buf[256];
    char* pbuf = buf;
    char* p = format;
    u32_t* pargs = (u32_t*)&format;
    pargs++;

    if (!format || !t_strlen(format))
        return;

    t_memset(buf, 0, 256);

    while (*p) 
    {
        if (*p == '%')
        {
            special = 1;
            switch (*(p + 1))
            {
            case 'c':
                p += 2; // skip "%c"
                *pbuf = (char)*pargs;
                pbuf++;
                pargs++;
                break;
            case 's':
                p += 2; // skip "%s"
                t_strcpy(pbuf, (char*)*pargs);
                pbuf += t_strlen(pbuf);
                pargs++;
                break;
            case 'd':
                p += 2; // skip "%d"
                t_ultoa(*pargs, pbuf, 10);
                pbuf += t_strlen(pbuf);
                pargs++;
                break;
            case 'x':
                p += 2; // skip "%x"
                t_ultoa(*pargs, pbuf, 16);
                pbuf += t_strlen(pbuf);
                pargs++;
                break;
            default:
                special = 0;
                break;
            }
        }
        
        /* normal char or broken '%' */
        if (!special)
        {
            *pbuf = *p;
            pbuf++;
            p++;
        }

        special = 0;
    }

    *pbuf = 0;

    print_string(buf);
}