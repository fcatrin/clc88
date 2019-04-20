#ifndef _FRONTEND_H
#define _FRONTEND_H


int  frontend_start_audio_stream(int stereo);
void frontend_stop_audio_stream();
int  frontend_update_audio_stream(INT16 *buffer);

int  frontend_init(int argc, char *argv[]);
int  frontend_init_screen(int width, int height);
void frontend_update_screen(void *pixels);
void frontend_done();

void frontend_sleep(int seconds);

#endif
