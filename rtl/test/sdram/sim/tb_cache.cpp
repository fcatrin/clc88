#include <stdlib.h>
#include <time.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcache.h"

#define MAX_SIM_TIME 200
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

vluint16_t memory[0x10000];
vluint8_t  code[0x10000];

typedef struct {
    vluint8_t  data_write;
    vluint8_t  data_read;
    vluint32_t address;
    vluint8_t  read_req;
    vluint8_t  write_req;
    vluint8_t  read_ack;
    vluint8_t  write_ack;
} device_t;

typedef struct {
    vluint32_t address;
    vluint16_t data_write;
    vluint16_t data_read;
    vluint8_t  read_req;
    vluint8_t  write_req;
    vluint8_t  read_ack;
    vluint8_t  write_ack;
} sdram_t;

typedef struct {
    vluint8_t  reset_n;
    vluint16_t pc;
    vluint16_t address;
    vluint16_t data_write;
    vluint16_t data_read;
    vluint8_t  read_req;
    vluint8_t  write_req;
    vluint8_t  read_ack;
    vluint8_t  write_ack;
    vluint8_t  reg_a;
    vluint8_t *code;
    vluint8_t  status;
} cpu_t;

enum DEVICE_STATUS {
    DEV_IDLE,
    DEV_WAIT_READ,
    DEV_WAIT_WRITE,
    DEV_READ
};

enum SDRAM_STATUS {
    SDRAM_IDLE,
    SDRAM_READ,
};

enum CPU_STATUS {
    CPU_EXEC,
    CPU_READ_WAIT,
    CPU_WRITE_WAIT,
    CPU_HALT
};

device_t device;
sdram_t sdram;
cpu_t cpu;
DEVICE_STATUS device_status = DEV_IDLE;

int (*test_read_func)();

void dut_reset(Vcache *dut, vluint64_t &sim_time){
    dut->reset_n = 1;
    if(sim_time < 2){
        dut->reset_n = 0;
    }
}

void dut_update_device_ports(Vcache *dut, vluint64_t &sim_time){
    device.read_req   = cpu.read_req;
    device.write_req  = cpu.write_req;
    device.address    = cpu.address;
    device.data_write = cpu.data_write;

    dut->data_write = device.data_write;
    dut->address    = device.address;
    dut->read_req   = device.read_req;
    dut->write_req  = device.write_req;

    device.data_read = dut->data_read;
    device.read_ack  = dut->read_ack;
    device.write_ack = dut->write_ack;

    cpu.read_ack  = device.read_ack;
    cpu.write_ack = device.write_ack;
    cpu.data_read = device.data_read;
    cpu.reset_n   = dut->reset_n;
}

void dut_update_sdram_ports(Vcache *dut, vluint64_t &sim_time){
    dut->sdram_data_read = sdram.data_read;
    dut->sdram_read_ack  = sdram.read_ack;
    dut->sdram_write_ack = sdram.write_ack;

    sdram.address    = dut->sdram_address;
    sdram.data_write = dut->sdram_data_write;
    sdram.read_req   = dut->sdram_read_req;
    sdram.write_req  = dut->sdram_write_req;
}
#define DATA_SIZE_TEST_1 40
vluint8_t* get_sequential_read_1_code() {
    for(int i=0; i<DATA_SIZE_TEST_1; i++) {
        code[i*3 + 0] = 0x02;
        code[i*3 + 1] = 0x21 + i;
        code[i*3 + 2] = 0x00;
    }
    return code;
}

#define DATA_SIZE_TEST_2 6
vluint8_t* get_sequential_read_2_code() {
    static vluint8_t addresses[] = {0, 1, 32, 33, 44, 45};
    for(int i=0; i<DATA_SIZE_TEST_2; i++) {
        code[i*3 + 0] = 0x02;
        code[i*3 + 1] = addresses[i];
        code[i*3 + 2] = 0x00;
    }
    return code;
}

#define DATA_SIZE_TEST_2 6
vluint8_t* get_sequential_read_3_code() {
    static vluint16_t addresses[] = {0, 1, 262, 263, 514, 515, 262, 263};
    for(int i=0; i<DATA_SIZE_TEST_2; i++) {
        vluint16_t address = addresses[i];
        code[i*3 + 0] = 0x02;
        code[i*3 + 1] = address & 0xff;
        code[i*3 + 2] = address >> 8;
    }
    return code;
}

vluint8_t* get_write_code() {
    static vluint8_t test_code[] = {
        1, 0x41, 3, 0x21, 0x00,
        1, 0x49, 3, 0x22, 0x00,
        2, 0x20, 0x00,
        2, 0x21, 0x00,
        2, 0x22, 0x00,
        2, 0x23, 0x00};
    return test_code;
}

int value_at(int address) {
    vluint16_t value = memory[address >> 1];
    return (address & 1) ? ((value & 0xff00) >> 8) : (value & 0x00ff);
}

void cpu_exec_instruction(vluint8_t instruction) {
    // printf("CPU pc:%04X EXEC %02X\n", cpu.pc, instruction);
    switch (instruction) {
        case 0x00:
            cpu.status = CPU_HALT;
            break;
        case 0x01:
            cpu.reg_a = cpu.code[cpu.pc++];
            break;
        case 0x02:
            cpu.address = cpu.code[cpu.pc] +  (cpu.code[cpu.pc+1] << 8);
            cpu.read_req = 1;
            cpu.pc += 2;
            cpu.status = CPU_READ_WAIT;
            break;
        case 0x03:
            cpu.address = cpu.code[cpu.pc] +  (cpu.code[cpu.pc+1] << 8);
            cpu.data_write = cpu.reg_a;
            cpu.write_req = 1;
            cpu.pc += 2;
            cpu.status = CPU_WRITE_WAIT;
            break;
    }
}

void cpu_exec() {
    if (!cpu.reset_n) return;

    switch(cpu.status) {
        case CPU_EXEC: {
                vluint8_t instruction = cpu.code[cpu.pc++];
                cpu_exec_instruction(instruction);
            }
            break;
        case CPU_READ_WAIT:
            if (cpu.read_ack) {
                cpu.read_req = 0;
                cpu.status = CPU_EXEC;
            }
            break;
        case CPU_WRITE_WAIT:
            if (cpu.write_ack) {
                cpu.write_req = 0;
                cpu.status = CPU_EXEC;
            }
            break;
        case CPU_HALT:
            break;
    }

    printf("CPU pc:%04X addr:%04X read_req:%d read_ack:%d write_req:%d write_ack:%d reg_a:%02X\n",
        cpu.pc, cpu.address, cpu.read_req, cpu.read_ack, cpu.write_req, cpu.read_ack, cpu.reg_a
    );

}

void dut_update_device_sim(Vcache *dut, vluint64_t &sim_time){
    static int read = 0;
    static int check_value = 0;
    if (read) {
        read = 0;
        printf("value read [%04x] = %02x(%c) == %02x(%c) %s\n",
            device.address, device.data_read, device.data_read,
            check_value, check_value, device.data_read == check_value ? "OK" : "FAILED");
    }
    switch(device_status) {
        case DEV_IDLE: {
            if (device.read_req) {
                device_status = DEV_WAIT_READ;
                check_value = value_at(device.address);
            }
            if (device.write_req) {
                device_status = DEV_WAIT_WRITE;
            }
        }
        break;
        case DEV_WAIT_READ:
            device.read_req = 0;
            if (device.read_ack) {
                device_status = DEV_IDLE;
                read = 1;
            }
        break;
        case DEV_WAIT_WRITE:
            device.write_req = 0;
            if (device.write_ack) {
                device_status = DEV_IDLE;
            }
        break;
    }

    if (device.write_ack) {
        printf("value write [%04x] = %02x\n",
            device.address, device.data_write);
    }
}

SDRAM_STATUS sdram_status = SDRAM_IDLE;
void dut_update_sdram_sim(Vcache *dut, vluint64_t &sim_time){
    static vluint16_t count;
    static vluint8_t  burst_count;
    static vluint32_t address;

    sdram.read_ack = 0;
    switch(sdram_status) {
        case SDRAM_IDLE:
            if (sdram.read_req) {
                count = 3;
                sdram_status = SDRAM_READ;
                address = sdram.address;
                burst_count = 8;
            }
            break;
        case SDRAM_READ:
            if (count > 0) {
                count--;
                if (count == 0) sdram.read_ack = 1;
            } else if (count == 0) {
                sdram.data_read = memory[address++];
                burst_count--;
                if (burst_count == 0) {
                    sdram_status = SDRAM_IDLE;
                }
            }
            break;
    }
}

void load_test_data() {
    FILE *f = fopen("testdata.txt", "rb");
    int n = fread(memory, 1, 0x20000, f);
    printf("read %d bytes\n", n);
    fclose(f);
}

void print_usage(char *name) {
    printf("Usage %s test_id\n", name);
    printf("\n\nTest ids:\n");
    printf("1 : sequential read, two lines\n");
    printf("2 : sequential read, two lines, two ways for one line\n");
    printf("3 : sequential read, two lines, one eviction\n");
    printf("4 : cache write\n");
    printf("5 : write back\n");
}

int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);
    if (argc < 2) {
        print_usage(argv[0]);
        exit(EXIT_FAILURE);
    }

    int test_id = atoi(argv[1]);
    if (test_id < 1 || test_id > 5) {
        print_usage(argv[0]);
        exit(EXIT_FAILURE);
    }

    memset(&cpu,    0, sizeof(cpu));
    memset(&device, 0, sizeof(device));
    memset(&sdram,  0, sizeof(sdram));
    memset(code,    0, sizeof(code));

    switch(test_id) {
        case 1: cpu.code = get_sequential_read_1_code(); break;
        case 2: cpu.code = get_sequential_read_2_code(); break;
        case 3: cpu.code = get_sequential_read_3_code(); break;
        case 4: cpu.code = get_write_code(); break;
    }

    load_test_data();
    srand(time(NULL));

    Vcache *dut = new Vcache;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        dut_reset(dut, sim_time);
        dut->sys_clk ^= 1;

        dut_update_device_ports(dut, sim_time);
        dut_update_sdram_ports(dut, sim_time);
        if (dut->sys_clk) {
            cpu_exec();
            posedge_cnt++;
            dut_update_device_sim(dut, sim_time);
            dut_update_sdram_sim(dut, sim_time);
        }
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
