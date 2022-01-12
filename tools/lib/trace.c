#include <stdio.h>
#include <stdarg.h>

int trace_enabled = 1;

void trace_msg(char *tag, ...) {
	va_list args;
	va_start(args, tag);
	char *format = va_arg(args, char *);

	fprintf(stdout, "[%s] ", tag);
	vfprintf(stdout, format, args);
	fprintf(stdout, "\n");
	va_end(args);

	fflush(stdout);
}

void trace_err(char *tag, ...) {

	va_list args;
	va_start(args, tag);
	char *format = va_arg(args, char *);

	fprintf(stderr, "[%s] ", tag);
	vfprintf(stderr, format, args);
	fprintf(stderr, "\n");
	va_end(args);

	fflush(stderr);
}
