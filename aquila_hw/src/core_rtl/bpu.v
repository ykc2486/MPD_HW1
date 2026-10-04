`timescale 1ns / 1ps
// =============================================================================
//  Program : bpu.v
//  Author  : Jin-you Wu
//  Date    : Jan/19/2019
// -----------------------------------------------------------------------------
//  Description:
//  This is the Branch Prediction Unit (BPU) of the Aquila core (A RISC-V core).
//  This module contains two branch prediction tables: BTB and BHT. The first one,
//  BTB, stores the TAG (address) of the branch instruction associated with each
//  branch instruction, along with the branch target address. The second one,
//  BHT, stores the likelihood of branching estimated from the past history.
//
//  Note that in this design, BTB and BHT are co-indexed becaused we assume a
//  1-to-1 mapping between a branch instruction and its likelihood to branch.
//  For a multi-level predictor such as GShare or TAGE, the mapping between the
//  BTB entries and BHT entries are not 1-to-1 so that the BHT entries must
//  additionally stores the indices to the BTB entries.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Feb/20/2020, by CY Hsiang:
//    Added the condition "~stall_i" to the "we" flag.
//
//  Aug/15/2020, by Chun-Jen Tsai:
//    Using a single BPU to handle both JAL and Branch instructions. In the
//    original code, an additional Unconditional Branch Prediction Unit (UC-BPU)
//    was used to handle the JAL instructions.
//
//  Aug/16/2023, by Chun-Jen Tsai:
//    Replace the fully associative BTB by a TAG-based direct-mapping BTB table.
//    The 2-bit Bimodal FSM is still used. The performance drops a little (0.03
//    DMIPS), but the resource usage drops significantly.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019 -,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity
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

module bpu #( parameter ENTRY_NUM = 64, parameter XLEN = 32 )
(
    // System signals
    input               clk_i,
    input               rst_i,
    input               stall_i,

    // from Program_Counter
    input  [XLEN-3 : 0] pc_i,     // Addr of the next instruction to fetch.

    // from Decode
    input  [XLEN-3 : 0] dec_pc_i, // Addr of the newly decoded instruction.
    input               is_jal_i,
    input               is_cond_branch_i,

    // from Execute
    input               exe_is_branch_i,
    input               branch_taken_i,
    input               branch_misprediction_i,
    input  [XLEN-3 : 0] branch_target_addr_i,

    // to Program_Counter
    output              btb_hit_o,
    output [XLEN-3 : 0] btb_target_addr_o,
    output              bht_taken_o
);

localparam NBITS = $clog2(ENTRY_NUM);

wire [NBITS-1 : 0]      read_addr;
wire [NBITS-1 : 0]      write_addr;
wire [XLEN-3 : 0]       branch_inst_tag;
wire                    we;
reg                     BPU_hit_ff, BPU_hit;

// Each entry in the Branch History Table (BHT) contains a two-bit
// saturating counter that stores the probability (likelihood) of
// taking the branch based on the past history of the current instruction.
reg  [1 : 0]            BHT[ENTRY_NUM-1 : 0];

// "we" is enabled to add a new entry to the BTB table when the decoded
// branch instruction is not in the BTB.
assign we = ~stall_i & (is_cond_branch_i | is_jal_i) & !BPU_hit;

// Direct-mapping indexing is used, so the least-significant NBITS
// word-address are used as the index to BTB and BHT.
assign read_addr = pc_i[NBITS-1 : 0];
assign write_addr = dec_pc_i[NBITS-1 : 0];

integer idx;

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            BHT[idx] <= 2'b00;
    end
    else if (stall_i)
    begin
        for (idx = 0; idx < ENTRY_NUM; idx = idx + 1)
            BHT[idx] <= BHT[idx];
    end
    else
    begin
        if (we) // Execute the branch instruction for the first time.
        begin
            BHT[write_addr] <= {branch_taken_i, branch_taken_i};
        end
        else if (exe_is_branch_i)
        begin
            case (BHT[write_addr])
`ifndef BAD
                2'b00:  // strongly not taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b01;
                    else
                        BHT[write_addr] <= 2'b00;
                2'b01:  // weakly not taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b11;
                    else
                        BHT[write_addr] <= 2'b00;
                2'b10:  // weakly taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b11;
                    else
                        BHT[write_addr] <= 2'b00;
                2'b11:  // strongly taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b11;
                    else
                        BHT[write_addr] <= 2'b10;
`else
                2'b00:  // strongly not taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b01;
                    else
                        BHT[write_addr] <= 2'b00;
                2'b01:  // weakly not taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b10;
                    else
                        BHT[write_addr] <= 2'b00;
                2'b10:  // weakly taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b11;
                    else
                        BHT[write_addr] <= 2'b01;
                2'b11:  // strongly taken
                    if (branch_taken_i)
                        BHT[write_addr] <= 2'b11;
                    else
                        BHT[write_addr] <= 2'b10;
`endif
            endcase
        end
    end
end

// ===========================================================================
//  Branch Target Buffer (BTB). Here, we use a direct-mapping cache table to
//  store the branch target PC value (if the decision is a "taken").
//  Each entry of BTB contains two fields: a 30-bit branch instruction address,
//  and a 30-bit branch target address. The branch instruction address is the TAG that is
//  used to make sure that cache collision did not happened.  
//
//  Since BTB requires more bits to store data, a distributed memory block,
//  instead of a register array, is used.
distri_ram #(.ENTRY_NUM(ENTRY_NUM), .DWIDTH((XLEN-2)*2))
BTB(
    .clk_i(clk_i),
    .we_i(we),                     // Write-enabled when the instruction at the Decode
                                   //   is a branch and has never been executed before.
    .write_addr_i(write_addr),     // Direct-mapping index for the branch at Decode.
    .read_addr_i(read_addr),       // Direct-mapping Index for the next PC to be fetched.

    // dec_pc_i is used for both "write_addr" and TAG
    .data_i({dec_pc_i, branch_target_addr_i}), // Input is only used when 'we' is 1.
    .data_o({branch_inst_tag, btb_target_addr_o})
);

// Delay the BHT hit flag at the Fetch stage for two clock cycles (plus stalls)
// such that it can be reused at the Execute stage for BHT update operation.
always @ (posedge clk_i)
begin
    if (rst_i) begin
        BPU_hit_ff <= 1'b0;
        BPU_hit <= 1'b0;
    end
    else if (!stall_i) begin
        BPU_hit_ff <= btb_hit_o;
        BPU_hit <= BPU_hit_ff;
    end
end

// ===========================================================================
//  Outputs signals
//
assign btb_hit_o = (branch_inst_tag == pc_i);
assign bht_taken_o = BHT[read_addr][1];

endmodule
