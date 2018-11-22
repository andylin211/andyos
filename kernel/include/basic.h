#ifndef _basic_h_
#define _basic_h_

#include "type.h"

void out_byte(u16_t port, u8_t val);

char in_byte(u16_t port);

void set_descriptor(descriptor_t* desc, u32_t base, u32_t limit, u16_t attr);

void set_gate(gate_t* gate, u32_t entry, u16_t attr);

#endif