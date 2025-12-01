//============================================================================
//  Sprint1 port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign VGA_DISABLE = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign AUDIO_MIX = 0;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = lamp;
assign BUTTONS = 0;
//assign FB_FORCE_BLANK = '0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

wire [1:0] ar = status[15:14];

assign VIDEO_ARX =  (!ar) ? ( 8'd4) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 8'd3) : 12'd0;



`include "build_id.v"
localparam CONF_STR = {
	"A.SPRINT1;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"O8,Oil Slicks,On,Off;",
	"O9,Cycle tracks,every lap,every two laps;",
	"OA,Extended Play,extended,normal;",
	"OBC,Game time,150 Sec,120 Sec,90 Sec,60 Sec;",
	"OD,Test,Off,On;",
	"OG,Color,Off,On;",		
	"-;",
	"R0,Reset;",
	"J1,Gas,GearUp,GearDown,Start 1P,Coin;",
	"jn,A,R,L,Start,X;",
	"V,v",`BUILD_DATE
};


wire [127:0] status;

wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);



wire m_left     =  joy[1];
wire m_right    =  joy[0];
wire m_gas      =  joy[4];
wire m_gearup   =  joy[5];
wire m_geardown =  joy[6];

wire m_start1   =  joy[7];
wire m_coin     =  joy[8];



/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Sprint 2 manual page 11 for complete information. Active low (0 = On, 1 = Off)
--    1 								Oil slicks			(0 - Oil slicks enabled)
--			2							Cycle tracks      (0/1 - Cycle every lap/every two laps)
--   			3	4					Coins per play		(00 - 1 Coin per player) 
--						5				Extended Play		(0 - Extended Play enabled)
--							6			Not used				(X - Don't care)
--								7	8	Game time			(01 - 120 Seconds)
--SW1 <= "01000101"; -- Config dip switches

Game Time:
0 0 - 150 seconds
0 1 - 120 seconds
1 0 -  90 seconds
1 1 - 60 seconds

*/
wire [7:0] SW1 = {status[8],status[9],1'b0,1'b0,status[10],1'b1,status[12:11]};


wire [1:0] steer;

joy2quad steer1
(
	.CLK(CLK_VIDEO_2),
	.clkdiv('d22500),
	
	.right(m_right),
	.left(m_left),
	
	.steer(steer)
);

wire gear1,gear2,gear3;
wire [2:0] gear;

gearshift gearshift1
(
	.CLK(clk_sys),
	.reset(m_start1),
	
	.gearup(m_gearup),
	.geardown(m_geardown),
	
	.gear1(gear1),
	.gear2(gear2),
	.gear3(gear3),
	.gearout(gear)
);



wire videowht,videoblk,compositesync,lamp;
wire [2:0] videorgb;

sprint1 sprint1(
	.Clk_50_I(CLK_50M),
	.Reset_n(~(RESET | status[0] | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.VideoW_O(videowht),
	.VideoB_O(videoblk),
	.VideoRGB_O(videorgb),
	
	.Sync_O(compositesync),
	.Audio1_O(audio),
	.Coin1_I(~(m_coin)),
	.Coin2_I(~(1'b0)),
	.Start_I(~(m_start1)),
	.Gas_I(~m_gas),
	.Gear1_I(gear1),
	.Gear2_I(gear2),
	.Gear3_I(gear3),
	.gear_shift(gear),
	.Test_I	(~status[13]),
	.SteerA_I(steer[1]),
	.SteerB_I(steer[0]),
	.StartLamp_O(lamp),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_12),
	.clk_6_O(CLK_VIDEO_2),
	.SW1_I(SW1)
	);
			
wire [6:0] audio;
wire [1:0] video;

///////////////////////////////////////////////////
wire clk_48,clk_12,CLK_VIDEO_2;
wire clk_sys,locked;
reg [7:0] vid_mono;
wire[1:0] sprint_vid;

always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			//2'b01: vid_mono<=8'b01010000;
			2'b01: vid_mono<=8'b01110000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign r=status[16] ? {3{videorgb[2]}} : vid_mono[7:5];
assign g=status[16] ? {3{videorgb[1]}} : vid_mono[7:5];
assign b=status[16] ? {3{videorgb[0]}} : vid_mono[7:5];

assign AUDIO_L={audio,1'b0,8'b00000000};
assign AUDIO_R=AUDIO_L;
assign AUDIO_S = 0;

wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;

reg ce_pix;
always @(posedge clk_48) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

arcade_video #(320,9,1) arcade_video
(
        .*,

        .clk_video(clk_48),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_48),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;

endmodule
