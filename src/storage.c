#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <pthread.h>
#include <dirent.h>


#include "emu.h"
#include "utils.h"

#define LOGTAG "STORAGE"
#ifdef TRACE_STORAGE
#define TRACE
#endif
#include "trace.h"

#define FILENAME_MAX_SIZE 1000

#define RET_SUCCESS             0x00
#define ERR_INVALID_OPERATION   0x80
#define ERR_FILE_NOT_FOUND      0x81
#define ERR_EOF                 0x82
#define ERR_IO                  0x83
#define ERR_TOO_MANY_OPEN_FILES 0x84
#define ERR_INVALID_FILE        0x85

#define CMD_OPEN  0x01
#define CMD_CLOSE 0x02
#define CMD_READ_BYTE   0x03
#define CMD_READ_SECTOR 0x04
#define CMD_DIR_OPEN    0x05
#define CMD_DIR_ENTRY   0x06
#define CMD_DIR_CLOSE   0x07

#define STATUS_IDLE       0x00
#define STATUS_PROCESSING 0x01
#define STATUS_DONE       0xFF

#define reg_proceed      0x00
#define reg_write_enable 0x01
#define reg_write_data   0x02
#define reg_read_enable  0x03
#define reg_read_data    0x04
#define reg_write_reset  0x05
#define reg_read_reset   0x06
#define reg_status       0x07

#define MAX_OPEN_FILES 128
FILE *file_handles[MAX_OPEN_FILES];

typedef struct dir_entry {
	char *name;
	unsigned size;
	char *date;
	char *time;
	bool is_dir;
	struct dir_entry *next;

} dir_entry;

dir_entry *dir_handles[MAX_OPEN_FILES];

#define CMD_MAX_SIZE 1024
#define RET_MAX_SIZE 1024
#define SECTOR_SIZE  256

UINT8 cmd[CMD_MAX_SIZE];
UINT8 ret[RET_MAX_SIZE];
UINT16 cmd_index = 0;
UINT16 ret_index = 0;

UINT8 write_data = 0;
UINT8 read_data  = 0;

UINT8 cmd_write_enable = 0;
UINT8 ret_read_enable = 0;

UINT8 status = 0;

pthread_t processor_thread;
bool processor_thread_running = FALSE;
bool process_command_enable   = FALSE;

static void cmd_write() {
	if (cmd_index < CMD_MAX_SIZE) {
		cmd[cmd_index++] = write_data;
	}
	cmd_write_enable = 0;
}
static void ret_data() {
	if (ret_index < RET_MAX_SIZE) {
		ret_read_enable = 0;
		read_data = ret[ret_index++];
	}
}

void storage_register_write(UINT8 index, UINT8 value) {
	switch(index) {
	case reg_write_enable:
		cmd_write_enable = value;
		if (cmd_write_enable) cmd_write();
		break;
	case reg_write_data:
		write_data = value;
		break;
	case reg_read_enable:
		ret_read_enable = value;
		if (ret_read_enable) ret_data();
		break;
	case reg_write_reset:
		cmd_index = 0;
		break;
	case reg_read_reset:
		ret_index = 0;
		break;
	case reg_proceed:
		process_command_enable = TRUE;
		break;
	}
}

UINT8 storage_register_read(UINT8 index) {
	switch(index) {
	case reg_write_enable:
		return cmd_write_enable;
	case reg_read_enable:
		return ret_read_enable;
	case reg_read_data:
		return read_data;
	case reg_status:
		if (status == STATUS_DONE) {
			status = STATUS_IDLE;
			return STATUS_DONE;
		}
		return status;
	}
	return 0;
}

static void cmd_storage_open() {
	char filename[FILENAME_MAX_SIZE+1];
	char *mode = (cmd[1] == 0) ? "rb":"wb";

	strncpy(filename, (char *)(cmd+2), FILENAME_MAX_SIZE);
	LOGV(LOGTAG, "try open file %s mode %s", filename, mode);
	FILE *file_handle = fopen(filename, mode);
	if (!file_handle) {
		LOGV(LOGTAG, "cannot open file %s err %s", filename, strerror(errno));
		ret[0] = 1;
		ret[1] = errno == ENOENT ? ERR_FILE_NOT_FOUND : ERR_IO;
		return;
	}

	for(int i=0; i<MAX_OPEN_FILES; i++) {
		if (!file_handles[i]) {
			file_handles[i] = file_handle;

			ret[0] = 2;
			ret[1] = RET_SUCCESS;
			ret[2] = i;
			return;
		}
	}

	ret[0] = 1;
	ret[1] = ERR_TOO_MANY_OPEN_FILES;
}

static FILE *get_file_handle(UINT8 file_handle_index) {
	if (file_handle_index < MAX_OPEN_FILES) {
		FILE *file_handle = file_handles[file_handle_index];
		if (file_handle) {
			return file_handle;
		} else {
			ret[0] = 1;
			ret[1] = ERR_INVALID_FILE;
		}
	}
	ret[0] = 1;
	ret[1] = ERR_INVALID_OPERATION;
	return NULL;
}

static void cmd_storage_close() {
	UINT8 file_handle_index = cmd[1];
	FILE *file_handle = get_file_handle(file_handle_index);
	if (!file_handle) return;

	fclose(file_handle);
	file_handles[file_handle_index] = NULL;
	ret[0] = 1;
	ret[1] = RET_SUCCESS;
}

static void cmd_read_byte() {
	FILE *file_handle = get_file_handle(cmd[1]);
	if (!file_handle) return;

	int c = fgetc(file_handle);
	if (c == EOF) {
		ret[0] = 1;
		ret[1] = ERR_EOF;
	} else {
		ret[0] = 2;
		ret[1] = RET_SUCCESS;
		ret[2] = c;
		LOGV(LOGTAG, "read byte %02X", c);
	}
}

static void cmd_read_sector() {
	FILE *file_handle = get_file_handle(cmd[1]);
	if (!file_handle) return;

	UINT8 buffer[SECTOR_SIZE];
	int n = fread(buffer, 1, SECTOR_SIZE, file_handle);
	if (n) {
		ret[0] = 3;
		ret[1] = RET_SUCCESS;
		ret[2] = n % SECTOR_SIZE;
		memcpy(&ret[3], buffer, n);
		LOGV(LOGTAG, "read block size %02X", n);
	} else if (feof(file_handle)) {
		ret[0] = 1;
		ret[1] = ERR_EOF;
		LOGV(LOGTAG, "read block EOF");
	} else {
		ret[0] = 1;
		ret[1] = ERR_IO;
	}
}

static int get_new_dir_handle() {
	for(int i=0; i<MAX_OPEN_FILES; i++) {
		if (!dir_handles[i]) return i;
	}
	return -1;
}

static void stat_dir_entry(char *dirname, dir_entry *entry) {
	static char name[FILENAME_MAX_SIZE];
	strcpy(name, dirname);
	strcat(name, "/");
	strcat(name, entry->name);

	static struct stat entry_stat;
	stat(name, &entry_stat);

	entry->size = entry_stat.st_size;
	entry->is_dir = S_ISDIR(entry_stat.st_mode);
	entry->date = utils_format_date(&entry_stat.st_mtim);
	entry->time = utils_format_time(&entry_stat.st_mtim);
}

static void cmd_read_dir() {
	int dir_handle = get_new_dir_handle();
	if (dir_handle < 0) {
		ret[0] = 1;
		ret[1] = ERR_TOO_MANY_OPEN_FILES;
		return;
	}

	char dirname[FILENAME_MAX_SIZE];
	if (cmd[1]) {
		strncpy(dirname, (char *)&cmd[1], FILENAME_MAX_SIZE);
	} else {
		strcpy(dirname, ".");
	}

	dir_entry *head = NULL;
	unsigned entries = 0;
	DIR *dir = opendir(dirname);
	if (dir) {
		struct dirent *dirent;
		while ((dirent = readdir(dir))!=NULL) {
			dir_entry *entry = malloc(sizeof(dir_entry));
			entry->name = strdup(dirent->d_name);
			entry->next = NULL;

			stat_dir_entry(dirname, entry);
			if (head == NULL) {
				head = entry;
				dir_handles[dir_handle] = head;
			} else {
				head->next = entry;
				head = entry;
			}
			entries++;
		}
	}
	closedir(dir);
	ret[0] = 4;
	ret[1] = RET_SUCCESS;
	ret[2] = dir_handle;
	ret[3] = entries & 0xFF;
	ret[4] = entries >> 8;
}

static dir_entry *get_dir_entries(int dir_handle) {
	dir_entry *entries = dir_handles[dir_handle];
	if (entries) return entries;

	ret[0] = 1;
	ret[1] = ERR_INVALID_FILE;
	return NULL;
}

static void cmd_get_dir_entry() {
	dir_entry *entry = get_dir_entries(cmd[1]);
	if (entry == NULL) return;

	unsigned index = cmd[2] + (cmd[3]<<8);
	while (index > 0 && entry->next != NULL) {
		index--;
		entry = entry->next;
	}

	cmd[0] = 0;
	cmd[1] = RET_SUCCESS;
	cmd[2] = entry->is_dir ? 1 : 0;
	cmd[3] = entry->size & 0xFF;
	cmd[4] = (entry->size & 0x0000FF00) >> 8;
	cmd[5] = (entry->size & 0x00FF0000) >> 16;
	cmd[6] = (entry->size & 0xFF000000) >> 24;
	strcpy((char *)&cmd[7], entry->date);
	strcpy((char *)&cmd[11], entry->time);
	strcpy((char *)&cmd[15], entry->name);
}

static void cmd_close_dir() {
	unsigned dir_index = cmd[1];
	dir_entry *entry = get_dir_entries(dir_index);
	if (entry == NULL) return;

	while (entry != NULL) {
		free(entry->name);
		free(entry->date);
		free(entry->time);

		dir_entry *next = entry->next;
		free(entry);
		entry = next;
	};

	cmd[0] = 1;
	cmd[1] = RET_SUCCESS;
}


static void process_command() {
	status = STATUS_PROCESSING;

	switch(cmd[0]) {
	case CMD_OPEN  :       cmd_storage_open();  break;
	case CMD_CLOSE :       cmd_storage_close(); break;
	case CMD_READ_BYTE :   cmd_read_byte();     break;
	case CMD_READ_SECTOR : cmd_read_sector();   break;
	case CMD_DIR_OPEN :    cmd_read_dir();      break;
	case CMD_DIR_ENTRY :   cmd_get_dir_entry(); break;
	case CMD_DIR_CLOSE :   cmd_close_dir();      break;
	}

	ret_index = 0;
	cmd_index = 0;
	ret_data();

	status = STATUS_DONE;
}

static void *processor_thread_function(void *data) {
	while(processor_thread_running) {
		if (process_command_enable) {
			process_command();
			process_command_enable = FALSE;
		} else {
			usleep(5000);
		}
	}
	return NULL;
}

void storage_init() {
	processor_thread_running = TRUE;
	int ret = pthread_create(&processor_thread, NULL, processor_thread_function, NULL);
	if (ret) {
		fprintf(stderr,"Error - pthread_create() return code: %d\n",ret);
		exit(EXIT_FAILURE);
	}
}

void storage_done() {
	processor_thread_running = FALSE;
	for(int i=0; i<MAX_OPEN_FILES; i++) {
		if (file_handles[i]) {
			fclose(file_handles[i]);
			file_handles[i] = 0;
		}
	}
	pthread_join(processor_thread, NULL);
}
