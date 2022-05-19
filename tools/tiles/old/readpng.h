#ifndef __READPNG_H
#define __READPNG_H

#define uch UINT8
#define ulg unsigned long

int readpng_init(FILE *infile, ulg *pWidth, ulg *pHeight);
uch *readpng_get_image(double display_exponent, int *pChannels, ulg *pRowbytes);
void readpng_cleanup(int free_image_data);

#endif