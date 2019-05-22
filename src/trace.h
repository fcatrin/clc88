#ifndef _TRACE_H_
#define _TRACE_H_

extern int trace_enabled;

#ifdef TRACE
	#ifdef __ANDROID__
		#include <android/log.h>
		#define LOGV(TAG, ...)   if (trace_enabled) __android_log_print((int)ANDROID_LOG_INFO, TAG, __VA_ARGS__)
		#define LOGE(TAG, ...)   if (trace_enabled) __android_log_print((int)ANDROID_LOG_ERROR, TAG, __VA_ARGS__)
	#else
		#include <stdarg.h>
		#define LOGV(TAG, ...)   if (trace_enabled) {fprintf(stdout, "[%s] ", TAG); fprintf(stdout, __VA_ARGS__); fprintf(stdout, "\n");}
		#define LOGE(TAG, ...)   if (trace_enabled) {fprintf(stderr, "[%s] ", TAG); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n");}
	#endif
#else
	#define LOGV(...)
	#define LOGE(...)
#endif

#endif
