#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcache.h"

#define MAX_SIM_TIME 60
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

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

enum DEVICE_STATUS {
    DEV_IDLE,
    DEV_WAIT_READ_0
};

enum SDRAM_STATUS {
    SDRAM_IDLE,
    SDRAM_READ,
};

device_t device;
sdram_t sdram;
DEVICE_STATUS device_status = DEV_IDLE;

void dut_reset(Vcache *dut, vluint64_t &sim_time){
    dut->reset_n = 1;
    if(sim_time < 2){
        dut->reset_n = 0;
    }
}

void dut_update_device_ports(Vcache *dut, vluint64_t &sim_time){
    dut->data_write = device.data_write;
    dut->address    = device.address;
    dut->read_req   = device.read_req;
    dut->write_req  = device.write_req;

    device.data_read = dut->data_read;
    device.read_ack  = dut->read_ack;
    device.write_ack = dut->write_ack;
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

void dut_update_device_sim(Vcache *dut, vluint64_t &sim_time){
    switch(device_status) {
        case DEV_IDLE: if (posedge_cnt == 4) {
            device.read_req = 1;
            device.address = 0x21;
            device_status = DEV_WAIT_READ_0;
        }
        break;
        case DEV_WAIT_READ_0: if (device.read_ack) {
            device_status = DEV_IDLE;
        }
        break;
    }
}

SDRAM_STATUS sdram_status = SDRAM_IDLE;
void dut_update_sdram_sim(Vcache *dut, vluint64_t &sim_time){
    static vluint16_t count;
    static vluint16_t sdram_data;
    static vluint8_t  burst_count;

    sdram.read_ack = 0;
    printf("sdram status: %d count:%d sdram_read_req:%d\n", sdram_status, count, sdram.read_req);
    switch(sdram_status) {
        case SDRAM_IDLE:
            if (sdram.read_req) {
                count = 3;
                sdram_status = SDRAM_READ;
                sdram_data   = 0x500 + sdram.address;
                burst_count = 8;
            }
            break;
        case SDRAM_READ:
            if (count > 0) {
                count--;
                if (count == 0) sdram.read_ack = 1;
            } else if (count == 0) {
                sdram.data_read = sdram_data++;
                burst_count--;
                if (burst_count == 0) {
                    sdram_status = SDRAM_IDLE;
                }
            }
            break;
    }
}

int main(int argc, char** argv, char** env) {
    Verilated::commandArgs(argc, argv);

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
