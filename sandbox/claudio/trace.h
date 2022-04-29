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
		#include "frontend/frontend.h"
		#define LOGV(TAG, ...)   if (trace_enabled) {frontend_trace_msg(TAG, __VA_ARGS__);}
		#define LOGE(TAG, ...)   if (trace_enabled) {frontend_trace_err(TAG, __VA_ARGS__);}
	#endif
#else
	#define LOGV(...)
	#define LOGE(...)
#endif

#endif
