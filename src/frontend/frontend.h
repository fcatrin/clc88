#ifndef _FRONTEND_H
#define _FRONTEND_H


int  osd_start_audio_stream(int stereo);
void osd_stop_audio_stream();
int  osd_update_audio_stream(INT16 *buffer);

#endif
