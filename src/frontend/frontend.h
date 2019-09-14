#ifndef _FRONTEND_H
#define _FRONTEND_H


int  frontend_start_audio_stream(int stereo);
void frontend_stop_audio_stream();
void frontend_update_audio_stream();

int  frontend_init(int argc, char *argv[]);
int  frontend_init_screen(int width, int height);
void frontend_update_screen(void *pixels);
void frontend_process_events();
void frontend_done();
void frontend_shutdown();
int  frontend_running();

void frontend_sleep(int seconds);

void frontend_trace_msg(char *tag, ...);
void frontend_trace_err(char *tag, ...);

UINT8 frontend_keyb_reg_read(UINT8 index);

#endif
