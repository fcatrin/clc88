#ifndef _TRACE_H_
#define _TRACE_H_

#ifdef TRACE
	#ifdef __ANDROID__
		#include <android/log.h>
		#define LOGV(...)   __android_log_print((int)ANDROID_LOG_INFO, "Compy", __VA_ARGS__)
		#define LOGE(...)   __android_log_print((int)ANDROID_LOG_ERROR, "Compy", __VA_ARGS__)
	#else
		#include <stdarg.h>
		#define LOGV(...)   fprintf(stdout, __VA_ARGS__); printf("\n")
		#define LOGE(...)   fprintf(stderr, __VA_ARGS__); printf("\n")
	#endif
#else
	#define LOGV(...)
	#define LOGE(...)
#endif

#endif
