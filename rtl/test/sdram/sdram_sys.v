`timescale 1ns / 1ps

module sdram_sys (
    input clk50,
    input key_reset,

    // SDRAM control
    output        S_CLK,  // SDRAM clock
    output        S_CKE,  // SDRAM clock enable
    output        S_NCS,  // SDRAM chip select
    output        S_NWE,  // SDRAM write enable
    output        S_NCAS, // SDRAM column address strobe
    output        S_NRAS, // SDRAM row address strobe
    output [1:0]  S_DQM,  // SDRAM data enable
    output [1:0]  S_BA,   // SDRAM bank address
    output [12:0] S_A,    // SDRAM address
    inout  [15:0] S_DB    // SDRAM data
    );

wire pll_locked;

reg boot_reset = 1;
reg user_reset = 0;

assign sys_reset = boot_reset || user_reset;

// keep reset until pll locks
always @ (posedge clk50) begin
  reg [20:0] counter = 21'd0;
  if (pll_locked) begin
     if (counter < 21'd2_000_000)  // 40ms at 40Mhz
        counter <= counter + 1'b1;
     else
        boot_reset <= 0;
  end
end

// handle user requested reset
always @ (posedge clk50) begin
  if (!key_reset_pressed && pll_locked) begin
     user_reset <= 1;
  end else begin
     user_reset <= 0;
  end
end

sdram_test sdram_test_inst (
  .clk(clk50),
  .reset_n(!sys_reset),
  .pll_locked(pll_locked),
  .S_CLK(S_CLK),
  .S_CKE(S_CKE),
  .S_NCS(S_NCS),
  .S_NWE(S_NWE),
  .S_NCAS(S_NCAS),
  .S_NRAS(S_NRAS),
  .S_DQM(S_DQM),
  .S_BA(S_BA),
  .S_A(S_A),
  .S_DB(S_DB)
);

wire key_reset_pressed;
debouncer debounce_key_reset (
  .clk(clk50),
  .in(key_reset),
  .out(key_reset_pressed)
);

endmodule
