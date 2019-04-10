#ifndef _FRONTEND_H
#define _FRONTEND_H


int  frontend_start_audio_stream(int stereo);
void frontend_stop_audio_stream();
int  frontend_update_audio_stream(INT16 *buffer);

#endif
