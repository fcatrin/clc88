#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcache.h"

#define MAX_SIM_TIME 20
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

enum DEVICE_STATUS {
    DEV_IDLE,
    DEV_WAIT_READ_0
};

device_t device;
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
        if (dut->sys_clk) {
            posedge_cnt++;
            dut_update_device_sim(dut, sim_time);
        }
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
