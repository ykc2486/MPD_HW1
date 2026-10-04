`timescale 1ns / 1ps
// =============================================================================
//  Program : forwarding_unit.v
//  Author  : Jin-you Wu
//  Date    : Dec/17/2018
// -----------------------------------------------------------------------------
//  Description:
//  This is the Data Forwarding Unit of the Aquila core (A RISC-V core).
//
//  The Data Forwarding Unit was based on the Microblaze-compatible processor,
//  KernelBlaze, originally designed by Dong-Fong Syu on Sep/01/2017.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  ??/??/2023, by Jung-Chun Tsai:
//    Added forward path to the Decode stage.
//  NONE.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
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

module forwarding_unit #( parameter XLEN = 32 )
(
    // Register data from Decode
    input  [4: 0]       dec2fwd_rs1_addr_i,
    input  [4: 0]       dec2fwd_rs2_addr_i,
    input  [11: 0]      dec2fwd_csr_addr_i,
    input  [XLEN-1 : 0] dec2fwd_rs1_data_i,
    input  [XLEN-1 : 0] dec2fwd_rs2_data_i,
    input  [XLEN-1 : 0] dec2fwd_csr_data_i,

    input  [4: 0]       dec2rfu_rs1_addr_i,
    input  [4: 0]       dec2rfu_rs2_addr_i,
    input  [11: 0]      dec2csr_csr_addr_i,

    input  [XLEN-1 : 0] rfu2fwd_rs1_data_i,
    input  [XLEN-1 : 0] rfu2fwd_rs2_data_i,
    input  [XLEN-1 : 0] csr2fwd_csr_data_i,

    // Register data from Execute
    input  [4: 0]       exe2mem_rd_addr_i,
    input               exe2mem_rd_we_i,
    input  [XLEN-1 : 0] exe2mem_p_data_i,

    input  [11: 0]      exe2mem_csr_addr_i,
    input               exe2mem_csr_we_i,
    input  [XLEN-1 : 0] exe2mem_csr_data_i,

    // Register data from Writeback
    input  [4: 0]       wbk2rfu_rd_addr_i,
    input               wbk2rfu_rd_we_i,
    input  [XLEN-1 : 0] wbk2rfu_rd_data_i,

    input               wbk2csr_csr_we_i,
    input  [11: 0]      wbk2csr_csr_addr_i,
    input  [XLEN-1 : 0] wbk2csr_csr_data_i,

    // to Decode Stage
    output [XLEN-1 : 0] fwd2dec_rs1_data_o,
    output [XLEN-1 : 0] fwd2dec_rs2_data_o,
    output [XLEN-1 : 0] fwd2dec_csr_data_o,

    // to Execution Stage
    output [XLEN-1 : 0] fwd2exe_rs1_data_o,
    output [XLEN-1 : 0] fwd2exe_rs2_data_o,
    output [XLEN-1 : 0] fwd2exe_csr_data_o
);

wire [XLEN-1 : 0] correct_fwd_src1, correct_fwd_src2;
wire is_WB_rd_addr_not_zero;

// ================================================================================
//  Forward to DEC input (from WB output)
//
wire is_rs1_rd_DEC_WB_same, is_rs2_rd_DEC_WB_same, is_csr_addr_DEC_WB_same;

wire rs1_DEC_WB_fwd, rs2_DEC_WB_fwd, csr_DEC_WB_fwd;
wire [XLEN-1 : 0] dec_correct_rs1_data, dec_correct_rs2_data, dec_correct_csr_data;

assign is_rs1_rd_DEC_WB_same      = (dec2rfu_rs1_addr_i == wbk2rfu_rd_addr_i);
assign is_rs2_rd_DEC_WB_same      = (dec2rfu_rs2_addr_i == wbk2rfu_rd_addr_i);
assign is_csr_addr_DEC_WB_same    = (dec2csr_csr_addr_i == wbk2csr_csr_addr_i);

assign is_WB_rd_addr_not_zero     = ( | wbk2rfu_rd_addr_i);

assign rs1_DEC_WB_fwd             = wbk2rfu_rd_we_i & is_rs1_rd_DEC_WB_same & is_WB_rd_addr_not_zero;
assign rs2_DEC_WB_fwd             = wbk2rfu_rd_we_i & is_rs2_rd_DEC_WB_same & is_WB_rd_addr_not_zero;
assign csr_DEC_WB_fwd             = wbk2csr_csr_we_i & is_csr_addr_DEC_WB_same;

assign dec_correct_rs1_data = rs1_DEC_WB_fwd ? correct_fwd_src2 : rfu2fwd_rs1_data_i;

assign dec_correct_rs2_data = rs2_DEC_WB_fwd ? correct_fwd_src2 : rfu2fwd_rs2_data_i;

assign dec_correct_csr_data = csr_DEC_WB_fwd ? wbk2csr_csr_data_i : csr2fwd_csr_data_i;

// ================================================================================
//  Forward to EXE input (from EXE or MEM output)
//
wire is_rs1_rd_EXE_MEM_same, is_rs2_rd_EXE_MEM_same, is_csr_addr_EXE_MEM_same;
wire is_rs1_rd_MEM_WB_same, is_rs2_rd_MEM_WB_same, is_csr_addr_MEM_WB_same;
wire is_EXE_rd_addr_not_zero;

wire rs1_EXE_MEM_fwd, rs2_EXE_MEM_fwd, csr_EXE_MEM_fwd;
wire rs1_MEM_WB_fwd, rs2_MEM_WB_fwd, csr_MEM_WB_fwd;

wire [XLEN-1 : 0] exe_correct_rs1_data, exe_correct_rs2_data, exe_correct_csr_data;

assign is_rs1_rd_EXE_MEM_same   = (dec2fwd_rs1_addr_i == exe2mem_rd_addr_i);
assign is_rs2_rd_EXE_MEM_same   = (dec2fwd_rs2_addr_i == exe2mem_rd_addr_i);
assign is_csr_addr_EXE_MEM_same = (dec2fwd_csr_addr_i == exe2mem_csr_addr_i);
assign is_rs1_rd_MEM_WB_same    = (dec2fwd_rs1_addr_i == wbk2rfu_rd_addr_i);
assign is_rs2_rd_MEM_WB_same    = (dec2fwd_rs2_addr_i == wbk2rfu_rd_addr_i);
assign is_csr_addr_MEM_WB_same  = (dec2fwd_csr_addr_i == wbk2csr_csr_addr_i);

assign is_EXE_rd_addr_not_zero  = ( | exe2mem_rd_addr_i);

assign rs1_EXE_MEM_fwd = exe2mem_rd_we_i & is_rs1_rd_EXE_MEM_same & is_EXE_rd_addr_not_zero;
assign rs2_EXE_MEM_fwd = exe2mem_rd_we_i & is_rs2_rd_EXE_MEM_same & is_EXE_rd_addr_not_zero;
assign csr_EXE_MEM_fwd = exe2mem_csr_we_i & is_csr_addr_EXE_MEM_same;

assign rs1_MEM_WB_fwd  = wbk2rfu_rd_we_i & is_rs1_rd_MEM_WB_same & is_WB_rd_addr_not_zero;
assign rs2_MEM_WB_fwd  = wbk2rfu_rd_we_i & is_rs2_rd_MEM_WB_same & is_WB_rd_addr_not_zero;
assign csr_MEM_WB_fwd  = wbk2csr_csr_we_i & is_csr_addr_MEM_WB_same;

assign correct_fwd_src1 = exe2mem_p_data_i; // 'd0, 'd1, 'd2 case will be handled by
                                            // pipeline_control (load-use data hazard)
assign correct_fwd_src2 = wbk2rfu_rd_data_i;

assign exe_correct_rs1_data =
       rs1_EXE_MEM_fwd ? correct_fwd_src1
       : rs1_MEM_WB_fwd ? correct_fwd_src2 : dec2fwd_rs1_data_i;

assign exe_correct_rs2_data =
       rs2_EXE_MEM_fwd ? correct_fwd_src1
       : rs2_MEM_WB_fwd ? correct_fwd_src2 : dec2fwd_rs2_data_i;

assign exe_correct_csr_data =
       csr_EXE_MEM_fwd ? exe2mem_csr_data_i
       : csr_MEM_WB_fwd ? wbk2csr_csr_data_i : dec2fwd_csr_data_i;

// ================================================================================
//  Outputs signals
//
assign fwd2dec_rs1_data_o = dec_correct_rs1_data;
assign fwd2dec_rs2_data_o = dec_correct_rs2_data;
assign fwd2dec_csr_data_o = dec_correct_csr_data;

assign fwd2exe_rs1_data_o = exe_correct_rs1_data;
assign fwd2exe_rs2_data_o = exe_correct_rs2_data;
assign fwd2exe_csr_data_o = exe_correct_csr_data;

endmodule   // forwarding

