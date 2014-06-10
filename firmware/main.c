#include <stdio.h>
#include <string.h>
#include "pp-printf.h"
#include "mini_sdb.h"
#include "sdb_arg.h"
#include "uart.h"
#include "irq.h"

void init()
{
   enable_irq();
   discoverPeriphery();
   uart_init_hw();
   uart_write_string("\nDebug Port\n");

}

int main(void) {

   init();

   pp_printf("FEC Unit starting!\n");
   pp_printf("SDB Record %x \n", r_sdb_add());


   while (1) {
  }

  disable_irq();
  return 0;

}
