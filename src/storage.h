#ifndef _STORAGE_H
#define _STORAGE_H

void  storage_register_write(UINT8 index, UINT8 value);
UINT8 storage_register_read(UINT8 index);

void storage_init();
void storage_done();

#endif
