#include "include/mm.h"
#include "include/const.h"
#include "include/global.h"
#include "include/t_stdio.h"
#include "include/t_string.h"

/*
* return base address of new page table
*/
static pte_t* new_page_table(void)
{
    g_page_table_count++;
    return (pte_t*)(g_page_table_base + (g_page_table_count - 1) * page_size);
}

static void update_page_table(u32_t va, u32_t pa)
{
    u32_t pdi = va >> 22;
    u32_t pti = (va >> 12) & 0x3ff;
    pte_t* pt = 0;

    /* not initialized */
    if (g_pdt[pdi] == 0)
    {
        pt = new_page_table();
        g_pdt[pdi] = ((u32_t)pt & 0xfffff000) + pde_default;
        pt[pti] = (pa & 0xfffff000) + pte_default;
    }
    else
    {
        pt = (pte_t*)((u32_t)g_pdt[pdi] & 0xfffff000);
        pt[pti] = (pa & 0xfffff000) + pte_default;
    }
}

static void actual_mapping(void)
{
    __asm 
    {
        mov        eax, [g_pdt]
        mov        cr3, eax
        mov        eax, cr0
        or         eax, cr0_page
        mov        cr0, eax
    }
}

/* for this 32MB memory */
void init_virtual_memory_mapping(void)
{
    int i = 0;
    //__asm jmp $
    g_page_directory_base = (g_kernel_image.image_base + g_kernel_image.data_base + g_kernel_image.data_size);
    g_page_directory_base = (((g_page_directory_base - 1) >> 12) + 1) << 12;
    g_pdt = (pde_t*)g_page_directory_base;
    t_memset(g_pdt, 0, page_size);
    g_page_table_base = g_page_directory_base + page_size;
    t_printf("pdb: 0x%x, ptb: 0x%x\r\n", g_page_directory_base, g_page_table_base);
    g_page_table_count = 0;
    
    /* 0x000000 ~ 0x100000 1MB for BIOS */
    for (i = 0; i < 0x100; i++)
    {
        update_page_table(i<<12, i<<12);
    }

    /* 0x400000 ~ 0x500000 1MB for image & page table */
    for (i = 0x400; i < 0x500; i++)
    {
        update_page_table(i << 12, i << 12);
    }

    actual_mapping();
}