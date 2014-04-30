/** @file irq.c
 *  @brief MSI IRQ handler for the LM32
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH
 *
 *  @author Mathias Kreider <m.kreider@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#include "irq.h"

#define NESTED_IRQS 0


const unsigned int IRQ_REG_RST   = 0x00000000;
const unsigned int IRQ_REG_STAT  = 0x00000004;
const unsigned int IRQ_REG_POP   = 0x00000008;
const unsigned int IRQ_OFFS_MSG  = 0x00000000;
const unsigned int IRQ_OFFS_ADR  = 0x00000004;
const unsigned int IRQ_OFFS_SEL  = 0x00000008;

inline void irq_pop_msi( unsigned int irq_no)
{
}

inline void isr_table_clr(void)
{
  //set all ISR table entries to Null
  unsigned int i;
  for(i=0;i<32;i++)  isr_ptr_table[i] = 0;
}

inline  unsigned int  irq_get_mask(void)
{
    //read IRQ mask
    unsigned int im;
    asm ( "rcsr %0, im": "=&r" (im));
    return im;
}


inline void irq_set_mask( unsigned int im)
{
    //write IRQ mask
    asm (   "wcsr im, %0" \
            :             \
            : "r" (im)    \
        );
}

inline  unsigned int  irq_get_enable(void)
{
    //read global IRQ enable bit
    unsigned int ie;
    asm ( "rcsr %0, ie\n"  \
          "andi %0, %0, 1" \
         : "=&r" (ie));
    return ie;
}

inline void irq_disable(void)
{
   //globally disable interrupts
   unsigned foo;
   asm volatile   (  "rcsr %0, IE\n"            \
                     "andi  %0, %0, 0xFFFE\n"   \
                     "wcsr IE, %0"              \
                     : "=r" (foo)               \
                     :                          \
                     :
                     );
}

inline void irq_enable(void)
{
   //globally enable interrupts
   unsigned foo;
   asm volatile   (  "rcsr %0, IE\n"      \
                     "ori  %0, %0, 1\n"   \
                     "wcsr IE, %0"        \
                     : "=r" (foo)         \
                     :                    \
                     :                    \
                     );
}


inline void irq_clear( unsigned int mask)
{
    //clear pending interrupt flag(s)
    asm           (  "wcsr ip, %0"  \
                     :              \
                     : "r" (mask)   \
                     :              \
                     );
}

void _irq_entry(void)
{
  unsigned int  ip;
  unsigned char irq_no = 0;
#if NESTED_IRQS
  unsigned int  msk;
#endif
  asm ("rcsr %0, ip": "=r"(ip)); //get pending flags
  while(ip)
  {
    if(ip & 1) //check if irq with lowest number is pending
    {
#if NESTED_IRQS
      msk = irq_get_mask();
      irq_set_mask(msk & ((1<<irq_no)-1) ); //mask out all priorities matching and below current
      irq_enable();
#endif
      irq_pop_msi(irq_no);      //pop msg from msi queue into global_msi variable
      irq_clear(1<<irq_no);     //clear pending bit
      isr_ptr_table[irq_no]();  //execute isr
#if NESTED_IRQS
      irq_set_mask(msk);
      irq_disable();
#endif
    }
    irq_no++;
    ip = ip >> 1; //process next irq
  }
}
