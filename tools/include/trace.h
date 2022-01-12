#ifndef _TRACE_H_
#define _TRACE_H_

extern int trace_enabled;

#ifdef TRACE
	#include <stdarg.h>
	void trace_msg(char *tag, ...);
	void trace_err(char *tag, ...);

	#define LOGV(TAG, ...)   if (trace_enabled) {trace_msg(TAG, __VA_ARGS__);}
	#define LOGE(TAG, ...)   if (trace_enabled) {trace_err(TAG, __VA_ARGS__);}
#else
	#define LOGV(...)
	#define LOGE(...)
#endif


#endif
