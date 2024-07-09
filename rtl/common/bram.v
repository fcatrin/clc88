// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module spram
      # (parameter depth = 256,
         parameter addr_width = 8,
         parameter data_width = 8)
        (address,
         clock,
         data,
         wren,
         byte_en,
         q);

   input [addr_width-1:0]  address;
   input   clock;
   input [data_width-1:0]  data;
   input   wren;
   input [(data_width / 8)-1:0] byte_en;
   output   [data_width-1:0]  q;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_off
   `endif
   tri1    clock;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_on
   `endif

   wire [data_width-1:0] sub_wire0;
   wire [data_width-1:0] q = sub_wire0[data_width-1:0];

   altsyncram  altsyncram_component (
         .address_a (address),
         .clock0 (clock),
         .data_a (data),
         .wren_a (wren),
         .q_a (sub_wire0),
         .aclr0 (1'b0),
         .aclr1 (1'b0),
         .address_b (1'b1),
         .addressstall_a (1'b0),
         .addressstall_b (1'b0),
         .byteena_a (data_width == 8 ? 1'b1 : byte_en),
         .clock1 (1'b1),
         .clocken0 (1'b1),
         .clocken1 (1'b1),
         .clocken2 (1'b1),
         .clocken3 (1'b1),
         .data_b (1'b1),
         .eccstatus (),
         .q_b (),
         .rden_a (1'b1),
         .rden_b (1'b1),
         .wren_b (1'b0));
   defparam
      altsyncram_component.byte_size = 8,
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_output_a = "BYPASS",
      altsyncram_component.intended_device_family = "Cyclone IV E",
      altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = depth,
      altsyncram_component.operation_mode = "SINGLE_PORT",
      altsyncram_component.outdata_aclr_a = "NONE",
      altsyncram_component.outdata_reg_a = "CLOCK0",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
      altsyncram_component.widthad_a = addr_width,
      altsyncram_component.width_a = data_width,
      altsyncram_component.width_byteena_a = (data_width / 8);
endmodule


module dpram 
      #( parameter depth = 256,
         parameter addr_width = 8,
         parameter data_width = 8)
       ( data,
         rdaddress,
         rdclock,
         wraddress,
         wrclock,
         wren,
         q);

   input [data_width-1:0]  data;
   input [addr_width-1:0]  rdaddress;
   input   rdclock;
   input [addr_width-1:0]  wraddress;
   input   wrclock;
   input   wren;
   output   [data_width-1:0]  q;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_off
   `endif
   tri1    wrclock;
   tri0    wren;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_on
   `endif

   wire [data_width-1:0] sub_wire0;
   wire [data_width-1:0] q = sub_wire0[data_width-1:0];

   altsyncram  altsyncram_component (
         .address_a (wraddress),
         .address_b (rdaddress),
         .clock0 (wrclock),
         .clock1 (rdclock),
         .data_a (data),
         .wren_a (wren),
         .q_b (sub_wire0),
         .aclr0 (1'b0),
         .aclr1 (1'b0),
         .addressstall_a (1'b0),
         .addressstall_b (1'b0),
         .byteena_a (1'b1),
         .byteena_b (1'b1),
         .clocken0 (1'b1),
         .clocken1 (1'b1),
         .clocken2 (1'b1),
         .clocken3 (1'b1),
         .data_b ({data_width{1'b1}}),
         .eccstatus (),
         .q_a (),
         .rden_a (1'b1),
         .rden_b (1'b1),
         .wren_b (1'b0));
   defparam
      altsyncram_component.address_aclr_b = "NONE",
      altsyncram_component.address_reg_b = "CLOCK1",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_input_b = "BYPASS",
      altsyncram_component.clock_enable_output_b = "BYPASS",
      altsyncram_component.intended_device_family = "Cyclone IV E",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = depth,
      altsyncram_component.numwords_b = depth,
      altsyncram_component.operation_mode = "DUAL_PORT",
      altsyncram_component.outdata_aclr_b = "NONE",
      altsyncram_component.outdata_reg_b = "CLOCK1",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.widthad_a = addr_width,
      altsyncram_component.widthad_b = addr_width,
      altsyncram_component.width_a = data_width,
      altsyncram_component.width_b = data_width,
      altsyncram_component.width_byteena_a = 1;
endmodule

module dpram_ab
    #(parameter depth = 256,
      parameter addr_width = 8,
      parameter data_width = 8)
     (address_a,
      address_b,
      address_en_a,
      address_en_b,
      clock,
      data_a,
      data_b,
      wren_a,
      wren_b,
      q_a,
      q_b);

   input [addr_width-1:0]  address_a;
   input [addr_width-1:0]  address_b;
   input   address_en_a;
   input   address_en_b;
   input   clock;
   input [data_width-1:0]  data_a;
   input [data_width-1:0]  data_b;
   input   wren_a;
   input   wren_b;
   output   [data_width-1:0]  q_a;
   output   [data_width-1:0]  q_b;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_off
   `endif
   tri1    clock;
   tri0    wren_a;
   tri0    wren_b;
   `ifndef ALTERA_RESERVED_QIS
      // synopsys translate_on
   `endif

   wire [data_width-1:0] sub_wire0;
   wire [data_width-1:0] sub_wire1;
   wire [data_width-1:0] q_a = sub_wire0[data_width-1:0];
   wire [data_width-1:0] q_b = sub_wire1[data_width-1:0];

   altsyncram  altsyncram_component (
         .address_a (address_a),
         .address_b (address_b),
         .clock0 (clock),
         .data_a (data_a),
         .data_b (data_b),
         .wren_a (wren_a),
         .wren_b (wren_b),
         .q_a (sub_wire0),
         .q_b (sub_wire1),
         .aclr0 (1'b0),
         .aclr1 (1'b0),
         .addressstall_a (!address_en_a),
         .addressstall_b (!address_en_b),
         .byteena_a (1'b1),
         .byteena_b (1'b1),
         .clock1 (1'b1),
         .clocken0 (1'b1),
         .clocken1 (1'b1),
         .clocken2 (1'b1),
         .clocken3 (1'b1),
         .eccstatus (),
         .rden_a (1'b1),
         .rden_b (1'b1));
   defparam
      altsyncram_component.address_reg_b = "CLOCK0",
      altsyncram_component.clock_enable_input_a = "BYPASS",
      altsyncram_component.clock_enable_input_b = "BYPASS",
      altsyncram_component.clock_enable_output_a = "BYPASS",
      altsyncram_component.clock_enable_output_b = "BYPASS",
      altsyncram_component.indata_reg_b = "CLOCK0",
      altsyncram_component.intended_device_family = "Cyclone IV E",
      altsyncram_component.lpm_type = "altsyncram",
      altsyncram_component.numwords_a = depth,
      altsyncram_component.numwords_b = depth,
      altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
      altsyncram_component.outdata_aclr_a = "NONE",
      altsyncram_component.outdata_aclr_b = "NONE",
      altsyncram_component.outdata_reg_a = "CLOCK0",
      altsyncram_component.outdata_reg_b = "CLOCK0",
      altsyncram_component.power_up_uninitialized = "FALSE",
      altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
      altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_WITH_NBE_READ",
      altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_WITH_NBE_READ",
      altsyncram_component.widthad_a = addr_width,
      altsyncram_component.widthad_b = addr_width,
      altsyncram_component.width_a = data_width,
      altsyncram_component.width_b = data_width,
      altsyncram_component.width_byteena_a = 1,
      altsyncram_component.width_byteena_b = 1,
      altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";


endmodule
