CROSS_COMPILE ?= lm32-elf-
export CROSS_COMPILE

CC =    $(CROSS_COMPILE)gcc
LD =    $(CROSS_COMPILE)ld
OBJDUMP = $(CROSS_COMPILE)objdump
OBJCOPY = $(CROSS_COMPILE)objcopy
SIZE =    $(CROSS_COMPILE)size

CONFIG_RAMSIZE = 90112
WRPC     := ../../../ip_cores/wrpc-sw
ARCH		 := ./arch/lm32
HW			 := ./hw
PRINT 	 := ./printf
SDB			 := ./sdb
CFLAGS   := -Wall -mmultiply-enabled -mbarrel-shift-enabled -Os 
#CFLAGS   += -I$(WRPC)/include -I$(WRPC)/pp_printf/ -I./ -I$(ARCH) -I$(SDB) -I$(PRINT) -I$(HW)
CFLAGS   += -I./ -I$(ARCH) -I$(SDB) -I$(PRINT) -I$(HW)
OUTPUT   := fec_dec
SRCS     := $(ARCH)/irq.c $(SDB)/mini_sdb.c $(PRINT)/mprintf.c  $(PRINT)/uart.c $(SDB)/sdb_arg.c main.c
ASS_SRCS := $(ARCH)/sdb_add.S $(ARCH)/crt0.S
OBJ      := $(SRCS:.c=.o) 
OBJ      += $(ASS_SRCS:.S=.o)
CLEAN    :=	*.o *.elf *.bin *.mif

all: $(OUTPUT).elf $(OUTPUT).mif

$(OUTPUT).elf: $(OBJ)
	$(CC) $(CFLAGS) -o $@ -nostdlib -T $(ARCH)/linker.ld $^
	$(SIZE) $@

%.mif: %.elf
	../../../ip_cores/wrpc-sw/tools/genrammif $*.elf $(CONFIG_RAMSIZE) > $@

clean:
	rm -f $(HW)/$(CLEAN) $(ARCH)/$(CLEAN) $(PRINT)/$(CLEAN) $(SDB)/$(CLEAN) $(CLEAN)
