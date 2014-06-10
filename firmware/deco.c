#include "irq.h"
#include "pp-printf.h"


void _irq_entry(void)
{
//  unsigned int  ip;
//  unsigned char irq_no = 0;
//  unsigned int  msk;
//
//  asm ("rcsr %0, ip": "=r"(ip)); //get pending flags
//
//  while(ip)
//  {
//    if(ip & 1) //check if irq with lowest number is pending
//    {
//      irq_clear(1<<irq_no);     //clear pending bit
//      irq_disable();
//    }
//    irq_no++;
//    ip = ip >> 1; //process next irq
//  }
  pp_printf("Interrupt!!! \n");
  pp_printf("IRQ bit %d \n", irq_get_enable());
  pp_printf("IRQ mask %d \n", irq_get_mask());
  clear_irq();
  pp_printf("IRQ bit %d \n", irq_get_enable());
}
