#include "mini_sdb.h"

unsigned char *find_device_deep(unsigned int base, unsigned int sdb,
                                       unsigned int devid)
{
        sdb_record_t *record = (sdb_record_t *) sdb;
        int records = record->interconnect.sdb_records;
        int i;

        for (i = 0; i < records; ++i, ++record) {
                if (record->empty.record_type == SDB_BRIDGE) {

                        unsigned char *out =
                            find_device_deep(base +  record->bridge.sdb_component.
					                                      addr_first.low,
					                                      base + record->bridge.sdb_child.low,
					                                      devid);
                        if (out)
                                return out;
                }
                if (record->empty.record_type == SDB_DEVICE &&
                    record->device.sdb_component.product.device_id == devid) {
                        break;
                }
        }

        if (i == records)
                return 0;
        return (unsigned char *)(base +
                                 record->device.sdb_component.addr_first.low);
}

unsigned char *find_device(unsigned int devid, unsigned int sdb_base)
{
        return find_device_deep(0, sdb_base, devid);
}

void discoverPeriphery(unsigned int sdb_base)
{
   pCpuId         = (unsigned int*)find_device(CPU_INFO_ROM, sdb_base);
   pCpuAtomic     = (unsigned int*)find_device(CPU_ATOM_ACC, sdb_base);
   pCluInfo       = (unsigned int*)find_device(CPU_CLU_INFO_ROM, sdb_base);
   pCpuSysTime    = (unsigned int*)find_device(CPU_SYSTEM_TIME, sdb_base);

   pCpuIrqSlave   = (unsigned int*)find_device(IRQ_MSI_CTRL_IF, sdb_base);
   pCpuTimer      = (unsigned int*)find_device(IRQ_TIMER_CTRL_IF, sdb_base);

   pFpqCtrl       = (unsigned int*)find_device(FTM_PRIOQ_CTRL, sdb_base);
   pFpqData       = (unsigned int*)find_device(FTM_PRIOQ_DATA, sdb_base);

   pOledDisplay   = (unsigned int*)find_device(OLED_DISPLAY, sdb_base);
   pEbm           = (unsigned int*)find_device(ETHERBONE_MASTER, sdb_base);
   pEca           = (unsigned int*)find_device(ECA_EVENT, sdb_base);
   pUart          = (unsigned int*)find_device(WR_UART, sdb_base);
   BASE_UART      = pUart; //make WR happy ...
}

