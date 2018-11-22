#include "include/const.h"
#include "include/global.h"
#include "include/basic.h"
#include "include/8259a.h"


static void blink(u32_t i)
{
	char* p = (char*)(screen_init_cursor + 2 * i + 1);
	u8_t fg = *p & 0x7;
	fg++;

	*p = (*p & 0xf8) | fg;
}

static void schedule(void)
{
	g_proc_running->ticks--;
	if (g_proc_running->ticks > 0)
		return;

	g_proc_running->ticks = g_proc_running->priority;
	g_proc_running = (g_proc_running == g_pcb) ? &g_pcb[1] : g_pcb;
}

static void clock_handler()
{
    g_ticks++;
	
    blink(0);
    schedule();
}

void init_clock(void)
{
    out_byte(timer_mode, rate_generator);

	out_byte(timer0, count_down_high);
	out_byte(timer0, count_down_low);

    put_irq_handler(irq_clock, clock_handler);
    enable_irq(irq_clock);
}
