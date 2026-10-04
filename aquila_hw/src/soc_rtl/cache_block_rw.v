`timescale 1 ns / 1 ps
// =============================================================================
//  Program : cache_block_rw.v
//  Author  : Tzu-Chen Yang
//  Date    : Apr/1/2025
// -----------------------------------------------------------------------------
//  Description:
//  This module read/write a cache block of data from the DDRx memory controller.
//  The native interface bus width of the MIG memory controller is of MBSIZE bits,
//  which may not match the cache block size of the cache controller.
//
//  Currently, this module only handles 128/256-bit DDR to 256-bit cache block
//  size conversion.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Aug/01/2026, by Chun-Jen Tsai:
//    Modify the code to handle MBSIZE of 128, 256, and 512 bits. Also, change
//    the input and output data width to both CLSIZE bits.
//    The MMU of Aquila require the cache size to be 256-bit. If the DRAM block
//    size is 128-bit (e.g., on Arty or QMCore), it takes two cycles to read/write
//    a cache block. On the other hand, if the memory block size is greater or
//    equal to the cache line size, this module will be a pass-thru module
//    between the Memory Arbiter and the CDC synchronizer.
//
//    *** Note:
//        This module should be merged into Memory Arbiter such that all the
//        platform-dependent DRAM parameters can be constrained in one module.
//
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause License,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2025,
//                    Department of Computer Science
//                    National Yang Ming Chiao Tung University
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"
`include "ddr_config.vh"

module  cache_block_rw
#(
  parameter XLEN = 32,
  parameter CLSIZE = 256,    // Cache line size.
  parameter MBSIZE = `WDFP   // Memory block size.
)
(
    // system signals
    input                    clk_i,
    input                    rst_i,

    // Cache controller signals
    input                    C_IMEM_strobe_i,
    input      [XLEN-1:0]    C_IMEM_addr_i,
    output                   C_IMEM_done_o,
    output     [CLSIZE-1:0]  C_IMEM_data_o,

    input                    C_DMEM_strobe_i,
    input      [XLEN-1:0]    C_DMEM_addr_i,
    input      [CLSIZE-1:0]  C_DMEM_data_i,
    input                    C_DMEM_rw_i,
    output                   C_DMEM_done_o,
    output     [CLSIZE-1:0]  C_DMEM_data_o,
    
    // Main memory signals
    output reg               M_IMEM_strobe_o,
    output     [XLEN-1:0]    M_IMEM_addr_o,
    input      [CLSIZE-1:0]  M_IMEM_data_i,
    input                    M_IMEM_done_i,

    output reg               M_DMEM_strobe_o,
    output     [XLEN-1:0]    M_DMEM_addr_o,
    input      [CLSIZE-1:0]  M_DMEM_data_i,
    input                    M_DMEM_done_i,
    output     [CLSIZE-1:0]  M_DMEM_data_o,
    output                   M_DMEM_rw_o
);

`ifdef DRAM_BLK_128 // CLSIZE == MBSIZE*2, Must read twice to fill up a cache block.

// Instruction memory signals
reg  [1:0] IMEM_S, IMEM_S_next;
reg  [XLEN-1:0] IMEM_addr_r;
reg  IMEM_strobe_r;
wire IMEM_strobe;
reg  [MBSIZE-1:0] imem_data_reg_0;

// Data memory signals
reg  [1:0] DMEM_S, DMEM_S_next;
reg  [XLEN-1:0] DMEM_addr_r;
reg  [CLSIZE-1:0] DMEM_data_r;
wire DMEM_strobe;
reg  DMEM_strobe_r;
reg  DMEM_rw_r;
reg  [MBSIZE-1:0] dmem_data_reg_0;

localparam S_IDLE = 2'b00;
localparam S_IMEM_STROBE_0 = 2'b01;
localparam S_IMEM_STROBE_1 = 2'b10;
localparam S_DMEM_STROBE_0 = 2'b01;
localparam S_DMEM_STROBE_1 = 2'b10;

// FSM for instruction cache block I/O
always @(posedge clk_i) begin
  if (rst_i) IMEM_S <= S_IDLE;
  else IMEM_S <= IMEM_S_next;
end

always @(*) begin
  case (IMEM_S)
    S_IDLE: IMEM_S_next = (C_IMEM_strobe_i)? S_IMEM_STROBE_0 : S_IDLE;
    S_IMEM_STROBE_0: IMEM_S_next = (M_IMEM_done_i)? S_IMEM_STROBE_1 : S_IMEM_STROBE_0;
    S_IMEM_STROBE_1: IMEM_S_next = (M_IMEM_done_i)? S_IDLE : S_IMEM_STROBE_1; 
    default: IMEM_S_next = S_IDLE;
  endcase
end

always @(posedge clk_i)begin
  if (rst_i) imem_data_reg_0 <= 0;
  else if (IMEM_S == S_IMEM_STROBE_0 && M_IMEM_done_i) imem_data_reg_0 <= M_IMEM_data_i[MBSIZE-1:0];
  else if (IMEM_S == S_IDLE) imem_data_reg_0 <= 0;
  else imem_data_reg_0 <= imem_data_reg_0;
end

assign IMEM_strobe = (IMEM_S == S_IMEM_STROBE_0 || IMEM_S == S_IMEM_STROBE_1) && !M_IMEM_done_i;

always @(posedge clk_i)begin
  if (rst_i) IMEM_strobe_r <= 0;
  else IMEM_strobe_r <= IMEM_strobe;
end

always @(posedge clk_i)begin
  if (rst_i) M_IMEM_strobe_o <= 0;
  else if (IMEM_strobe && !IMEM_strobe_r) M_IMEM_strobe_o <= 1;
  else M_IMEM_strobe_o <= 0;
end

assign M_IMEM_addr_o = (IMEM_S == S_IMEM_STROBE_0)? IMEM_addr_r : IMEM_addr_r + 32'd16;

always @(posedge clk_i)begin
  if (rst_i) begin
    IMEM_addr_r <= 0;
  end else if (C_IMEM_strobe_i) begin
    IMEM_addr_r <= C_IMEM_addr_i;
  end else if (IMEM_S == S_IDLE) begin
    IMEM_addr_r <= 0;
  end
end

assign C_IMEM_done_o = (IMEM_S == S_IMEM_STROBE_1 && M_IMEM_done_i);
assign C_IMEM_data_o = {imem_data_reg_0, M_IMEM_data_i[MBSIZE-1:0]};

// FSM for data cache block I/O
always @(posedge clk_i)begin
  if (rst_i) DMEM_S <= S_IDLE;
  else DMEM_S <= DMEM_S_next;
end

always @(*) begin
  case (DMEM_S)
    S_IDLE: DMEM_S_next = (C_DMEM_strobe_i)? S_DMEM_STROBE_0 : S_IDLE;
    S_DMEM_STROBE_0: DMEM_S_next = (M_DMEM_done_i)? S_DMEM_STROBE_1 : S_DMEM_STROBE_0;
    S_DMEM_STROBE_1: DMEM_S_next = (M_DMEM_done_i)? S_IDLE : S_DMEM_STROBE_1; 
    default: DMEM_S_next = S_IDLE;
  endcase
end

always @(posedge clk_i) begin
  if (rst_i) dmem_data_reg_0 <= 0;
  else if (DMEM_S == S_DMEM_STROBE_0 && M_DMEM_done_i) dmem_data_reg_0 <= M_DMEM_data_i[MBSIZE-1:0];
  else if (DMEM_S == S_IDLE) dmem_data_reg_0 <= 0;
  else dmem_data_reg_0 <= dmem_data_reg_0;
end

assign DMEM_strobe = (DMEM_S == S_DMEM_STROBE_0 || DMEM_S == S_DMEM_STROBE_1) && !M_DMEM_done_i;

always @(posedge clk_i)begin
  if (rst_i) DMEM_strobe_r <= 0;
  else DMEM_strobe_r <= DMEM_strobe;
end

always @(posedge clk_i)begin
  if (rst_i) M_DMEM_strobe_o <= 0;
  else if (DMEM_strobe && !DMEM_strobe_r) M_DMEM_strobe_o <= 1;
  else M_DMEM_strobe_o <= 0;
end

assign M_DMEM_data_o = {{MBSIZE{1'b0}}, (DMEM_S == S_DMEM_STROBE_0)? DMEM_data_r[MBSIZE*2-1:MBSIZE] : DMEM_data_r[MBSIZE-1:0]};
assign M_DMEM_addr_o = (DMEM_S == S_DMEM_STROBE_0)? DMEM_addr_r : DMEM_addr_r + 16;
assign M_DMEM_rw_o = DMEM_rw_r;

always @(posedge clk_i)begin
  if (rst_i) begin
    DMEM_addr_r <= 0;
    DMEM_data_r <= 0;
    DMEM_rw_r <= 0;
  end else if (C_DMEM_strobe_i) begin
    DMEM_addr_r <= C_DMEM_addr_i;
    DMEM_data_r <= C_DMEM_data_i;
    DMEM_rw_r <= C_DMEM_rw_i;
  end else if (DMEM_S == S_IDLE) begin
    DMEM_addr_r <= 0;
    DMEM_data_r <= 0;
    DMEM_rw_r <= 0;
  end
end

assign C_DMEM_done_o = (DMEM_S == S_DMEM_STROBE_1 && M_DMEM_done_i);
assign C_DMEM_data_o = {dmem_data_reg_0, M_DMEM_data_i[MBSIZE-1:0]};

`else // for DRAM_BLK_256 and DRAM_BLK_512, the returned block from the Memory_Arbiter is of CLSIZE bits.
    assign C_IMEM_done_o = M_IMEM_done_i;
    assign C_IMEM_data_o = M_IMEM_data_i;
    assign C_DMEM_done_o = M_DMEM_done_i;
    assign C_DMEM_data_o = M_DMEM_data_i;

    always@(*) M_IMEM_strobe_o = C_IMEM_strobe_i;
    assign M_IMEM_addr_o       = C_IMEM_addr_i;
    always@(*) M_DMEM_strobe_o = C_DMEM_strobe_i;
    assign M_DMEM_addr_o       = C_DMEM_addr_i;
    assign M_DMEM_data_o       = C_DMEM_data_i;
    assign M_DMEM_rw_o         = C_DMEM_rw_i;
`endif

endmodule

