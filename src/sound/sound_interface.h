#ifndef _SOUND_INTERFACE_H
#define _SOUND_INTERFACE_H

struct MachineSound
{
	int sound_type;
	void *sound_interface;
	const char *tag;
};

int sound_scalebufferpos(int value);

#endif
