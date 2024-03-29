#ifndef __SYSTEM_H__
#define __SYSTEM_H__

void system_run(UINT32 microseconds);
bool system_has_irq();

void  system_register_write(UINT8 index, UINT8 value);
UINT8 system_register_read(UINT8 index);

#endif
