// 640x480 no borders
parameter Mode1_H_Display    = 12'd640;
parameter Mode1_H_FrontPorch = 12'd16;
parameter Mode1_H_SyncPulse  = 12'd96;
parameter Mode1_H_BackPorch  = 12'd48;
parameter Mode1_H_DeStart = Mode1_H_SyncPulse + Mode1_H_BackPorch;
parameter Mode1_H_DeEnd   = Mode1_H_DeStart   + Mode1_H_Display;
parameter Mode1_H_Total   = Mode1_H_DeEnd     + Mode1_H_FrontPorch;
parameter Mode1_H_PfStart = Mode1_H_DeStart;
parameter Mode1_H_PfEnd   = Mode1_H_DeEnd;
parameter Mode1_V_Display    = 12'd480;
parameter Mode1_V_FrontPorch = 12'd11;
parameter Mode1_V_SyncPulse  = 12'd2;
parameter Mode1_V_BackPorch  = 12'd31;
parameter Mode1_V_DeStart = Mode1_V_SyncPulse + Mode1_V_BackPorch;
parameter Mode1_V_DeEnd   = Mode1_V_DeStart   + Mode1_V_Display;
parameter Mode1_V_Total   = Mode1_V_DeEnd     + Mode1_V_FrontPorch;
parameter Mode1_V_PfStart = Mode1_V_DeStart;
parameter Mode1_V_PfEnd   = Mode1_V_DeEnd;
parameter Mode1_H_SyncP   = 1'b0;
parameter Mode1_V_SyncP   = 1'b0;

// 800x600 => 640x480 + borders
parameter Mode2_H_Display    = 12'd800;
parameter Mode2_H_FrontPorch = 12'd40;
parameter Mode2_H_SyncPulse  = 12'd128;
parameter Mode2_H_BackPorch  = 12'd88;
parameter Mode2_H_DeStart = Mode2_H_SyncPulse + Mode2_H_BackPorch;
parameter Mode2_H_DeEnd   = Mode2_H_DeStart   + Mode2_H_Display;
parameter Mode2_H_Total   = Mode2_H_DeEnd     + Mode2_H_FrontPorch;
parameter Mode2_H_PfStart = Mode2_H_DeStart   + 12'd80;
parameter Mode2_H_PfEnd   = Mode2_H_PfStart   + 12'd640;
parameter Mode2_V_Display  = 12'd600;
parameter Mode2_V_FrontPorch = 12'd1;
parameter Mode2_V_SyncPulse  = 12'd4;
parameter Mode2_V_BackPorch  = 12'd23;
parameter Mode2_V_DeStart = Mode2_V_SyncPulse + Mode2_V_BackPorch;
parameter Mode2_V_DeEnd   = Mode2_V_DeStart   + Mode2_V_Display;
parameter Mode2_V_Total   = Mode2_V_DeEnd     + Mode2_V_FrontPorch;
parameter Mode2_V_PfStart = Mode2_V_DeStart   + 12'd60;
parameter Mode2_V_PfEnd   = Mode2_V_PfStart   + 12'd480;
parameter Mode2_H_SyncP   = 1'b0;
parameter Mode2_V_SyncP   = 1'b0;

// Modeline "1920x1080_60.00" 172.80 1920 2040 2248 2576 1080 1081 1084 1118 -HSync +Vsync

// 1920x1080 => Allow 4x and 5x scaling mode. 5x assumes screens with a visible area of 320x216 pixels max
parameter Mode3_H_Display    = 12'd1920;
parameter Mode3_H_FrontPorch = 12'd88;
parameter Mode3_H_SyncPulse  = 12'd44;
parameter Mode3_H_BackPorch  = 12'd148;
parameter Mode3_H_DeStart = Mode3_H_SyncPulse + Mode3_H_BackPorch;
parameter Mode3_H_DeEnd   = Mode3_H_DeStart   + Mode3_H_Display;
parameter Mode3_H_Total   = Mode3_H_DeEnd     + Mode3_H_FrontPorch;
parameter Mode3_H_PfStart = Mode3_H_DeStart   + 12'd320;
parameter Mode3_H_PfEnd   = Mode3_H_PfStart   + 12'd1280;
parameter Mode3_V_Display    = 12'd1080;
parameter Mode3_V_FrontPorch = 12'd4;
parameter Mode3_V_SyncPulse  = 12'd5;
parameter Mode3_V_BackPorch  = 12'd36;
parameter Mode3_V_DeStart = Mode3_V_SyncPulse + Mode3_V_BackPorch;
parameter Mode3_V_DeEnd   = Mode3_V_DeStart   + Mode3_V_Display;
parameter Mode3_V_Total   = Mode3_V_DeEnd     + Mode3_V_FrontPorch;
parameter Mode3_V_PfStart = Mode3_V_DeStart   + 12'd64;
parameter Mode3_V_PfEnd   = Mode3_V_PfStart   + 12'd960;
parameter Mode3_H_SyncP   = 1'b0;
parameter Mode3_V_SyncP   = 1'b1;

/*

Output Modes target different monitor setups and preferences about borders/overscan.
Supported monitors are WIDE (16:9) and NONWIDE (4:3)

Mode1 and Mode2 are designed to be used with NONWIDE monitors. With and without overscan
Mode3 is designed for WIDE monitors. An overscan is added to keep the aspect ratio

The standard resolution is 320x240, although the 80 character mode is 640x240

*/
