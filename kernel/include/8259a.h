#ifndef _8259a_h_
#define _8259a_h_

#include "type.h"

void init_8259a(void);

void put_irq_handler(int irq, void* handler);

void enable_irq(u32_t irq);

void enable_irq(u32_t irq);

void eoi(void);

#endif
