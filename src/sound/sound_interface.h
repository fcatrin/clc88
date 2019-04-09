#ifndef SNDINTRF_H
#define SNDINTRF_H


struct MachineSound
{
	int sound_type;
	void *sound_interface;
	const char *tag;
};

#endif
