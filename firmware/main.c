#include <stdint.h>

#include <inttypes.h>
#include <stdarg.h>

#include "board.h"
#include <uart.h>
#include <mini_sdb.h>
#include <sdb_arg.h>
#include <mprintf.h>

//volatile unsigned int* pSDB_base;

void usleep(int x)
{
  int i;
  for (i = x * CPU_CLOCK/1000/4; i > 0; i--) asm("# noop");
}

void init() {

  discoverPeriphery(r_sdb_add());
	uart_init_hw();
	uart_write_string("Debug Port\n");

} //end of init()

int main(void)
{
  int a,b,c;
  a = 100;
  b = 200;
	//init();

	while(1) {
    c+= a<<1;
    //mprintf("HOLAAA \n");
	}
}
