#ifndef _string_h_
#define _string_h_

#include "type.h"


int t_memset(void* addr, u8_t val, int size);

int t_memcpy(void* dst, void* src, int size);

int t_strlen(char* str);

int t_strcpy(char* dst, char* src);


#endif

