#include "include/type.h"

/*
* radix = 10 or 16
*
*/
char* t_ultoa(u32_t digit, char* str, int radix)
{
    char* ret = str;
    static char buf[20] = { 0 };
    /* 4294967294 or ffff ffff */
    char* pbuf = buf;
    int count = 0;
    /* quotient remainder */
    int q, r;


    if (!str || (radix != 10 && radix != 16))
        return 0;

    if (radix == 10)
    {
        while (digit)
        {
            r = digit % radix;
            digit = q = digit / radix;
            
            *pbuf = r + '0';
            pbuf++;
            count++;
        }
    }

    if (radix == 16)
    {
        while (digit)
        {
            r = digit % radix;
            digit = q = digit / radix;

            *pbuf = (r >= 10) ? (r+'a'-10) : (r+'0');
            pbuf++;
            count++;
        }
    }

    while (count)
    {
        count--;
        pbuf--;

        *str = *pbuf;
        str++;
    }

    *str = 0;

    return ret;
}
