#ifndef __SERIAL
#define __SERIAL

int     semu_open();
void    semu_close();
UINT8   semu_receive();
void    semu_send(UINT8 data);
int     semu_has_data();

#endif
