`timescale 1ns / 1ps
// =============================================================================
//  Program : execute.v
//  Author  : Jin-you Wu
//  Date    : Dec/19/2018
// -----------------------------------------------------------------------------
//  Description:
//  This is the Execution Unit of the Aquila core (A RISC-V core).
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Nov/29/2019, by Chun-Jen Tsai:
//    Merges the pipeline register module 'execute_memory' into the 'execute'
//    module.
//
//  Aug/19/2025, by Sin-Ying Li:
//    Add RV32F execution via FPIP with FP operand selects.
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

module execute #( parameter XLEN = 32 )
(
    //  Processor clock and reset signals.
    input                   clk_i,
    input                   rst_i,

    // Pipeline stall signal.
    input                   stall_i,

    // Pipeline flush signal.
    input                   flush_i,

    // From Decode.
    input  [XLEN-1 : 0]     imm_i,
    input  [ 2 : 0]         inputA_sel_i,
    input  [ 2 : 0]         inputB_sel_i,
    input  [ 2 : 0]         operation_sel_i,
    input                   alu_muldiv_sel_i,
    input                   shift_sel_i,
    input                   is_branch_i,
    input                   is_jal_i,
    input                   is_jalr_i,
    input                   branch_hit_i,
    input                   branch_taken_i,

    input  [ 2 : 0]         rd_input_sel_i,
    input  [ 4 : 0]         rd_addr_i,
    input                   rd_we_i,
    input                   signex_sel_i,

    input                   we_i,
    input                   re_i,
    input  [ 1 : 0]         dsize_sel_i,
    input                   is_fencei_i,
    input                   is_amo_i,
    input  [4 : 0]          amo_type_i,

    // From CSR.
    input  [ 4 : 0]         csr_imm_i,
    input                   csr_we_i,
    input  [11 : 0]         csr_we_addr_i,

    // From the Forwarding Unit.
    input  [XLEN-1 : 0]     rs1_data_i,
    input  [XLEN-1 : 0]     rs2_data_i,
    input  [XLEN-1 : 0]     csr_data_i,

    // To the Program Counter Unit.
    output [XLEN-1 : 0]     branch_restore_pc_o,    // to PC only
    output [XLEN-1 : 0]     branch_target_addr_o,   // to PC and BPU

    // To the Pipeline Control and the Branch Prediction units.
    output                  is_branch_o,
    output                  branch_taken_o,
    output                  branch_misprediction_o,

    // Pipeline stall signal generator, activated when executing
    //    multicycle mul, div and rem instructions.
    output                  stall_from_exe_o,

    // Signals to D-memory.
    output reg              we_o,
    output reg              re_o,
    output reg              is_fencei_o,
    output reg              is_amo_o,
    output reg [ 4 : 0]     amo_type_o,

    // Signals to Memory Alignment unit.
    output reg [XLEN-1 : 0] rs2_data_o,
    output reg [XLEN-1 : 0] addr_o,
    output reg [ 1 : 0]     dsize_sel_o,
    
    // Signals to Memory Writeback Pipeline.
    output reg [ 2 : 0]     rd_input_sel_o,
    output reg              rd_we_o,
    output reg [ 4 : 0]     rd_addr_o,
    output reg [XLEN-1 : 0] p_data_o,

    output reg              csr_we_o,
    output reg [11 : 0]     csr_we_addr_o,
    output reg [XLEN-1 : 0] csr_we_data_o,

    // to Memory_Write_Back_Pipeline
    output reg              signex_sel_o,

    // PC of the current instruction.
    input  [XLEN-1 : 0]     pc_i,
    output reg [XLEN-1 : 0] pc_o,

    // System Jump operation
    input                   sys_jump_i,
    input  [ 1 : 0]         sys_jump_mode_i,
    output reg              sys_jump_o,
    output reg [ 1 : 0]     sys_jump_mode_o,

    // Has instruction fetch being successiful?
    input                   fetch_valid_i,
    output reg              fetch_valid_o,

`ifdef ENABLE_FPU
    // FPU related signals ------------------------------------------
    // Signals from Decode.
    input  [XLEN-1 : 0]     rs1_f_data_i,
    input  [XLEN-1 : 0]     rs2_f_data_i,
    input  [XLEN-1 : 0]     rs3_f_data_i,
    input  [ 2 : 0]         inputC_sel_i,

    input                   fp_op_i,
    input  [ 6 : 0]         fp_func_sel_i,
    input  [ 4 : 0]         fp_unit_sel_i,
    input                   rd_fpr_we_i,
    input                   fp32_load_i,
    input                   fp32_store_i,

    // Signals to D-Memory.
    output reg              fp32_load_o,

    // Signals to Memory stage and Forwarding unit.
    output reg              rd_fpr_we_o,
`endif // ENABLE_FPU

    // Exception info passed from Decode to Memory.
    input                   xcpt_valid_i,
    input  [ 3 : 0]         xcpt_cause_i,
    input  [XLEN-1 : 0]     xcpt_tval_i,
    output reg              xcpt_valid_o,
    output reg [ 3 : 0]     xcpt_cause_o,
    output reg [XLEN-1 : 0] xcpt_tval_o
);

// ===============================================================================
//  ALU input/output selection
//
reg  [XLEN-1 : 0] inputA, inputB;
wire [XLEN-1 : 0] alu_result;
wire              alu_stall;
wire [XLEN-1 : 0] muldiv_result;
wire              compare_result, stall_from_muldiv, muldiv_ready;

wire [XLEN-1 : 0] exe_result;
wire [XLEN-1 : 0] mem_addr;

always @(*)
begin
    case (inputA_sel_i)
        3'd0: inputA = 0;
        3'd1: inputA = pc_i;
        3'd2: inputA = rs1_data_i;
`ifdef ENABLE_FPU
        3'd3: inputA = {~rs1_f_data_i[31], rs1_f_data_i[30:0]};
        3'd4: inputA = rs1_f_data_i;
`endif
        default: inputA = 0;
    endcase
end

always @(*)
begin
    case (inputB_sel_i)
        3'd0: inputB = imm_i;
        3'd1: inputB = rs2_data_i;
        3'd2: inputB = ~rs2_data_i + 1'b1;
`ifdef ENABLE_FPU
        3'd3: inputB = rs2_f_data_i;
        3'd4: inputB = {~rs2_f_data_i[31], rs2_f_data_i[30:0]};
`endif
        default: inputB = 0;
    endcase
end

// branch target address generate by alu adder
wire [2: 0] alu_operation = (is_branch_i | is_jal_i | is_jalr_i)? 3'b000 : operation_sel_i;
wire [2: 0] muldiv_operation = operation_sel_i;
wire muldiv_req = alu_muldiv_sel_i & !muldiv_ready;
wire [2: 0] branch_operation = operation_sel_i;

// ===============================================================================
//  ALU Regular operation
//
alu ALU(
    .a_i(inputA),
    .b_i(inputB),
    .operation_sel_i(alu_operation),
    .shift_sel_i(shift_sel_i),
    .alu_result_o(alu_result)
);

// ===============================================================================
//   MulDiv
//
muldiv MulDiv(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .stall_i(stall_i),
    .a_i(inputA),
    .b_i(inputB),
    .req_i(muldiv_req),
    .operation_sel_i(muldiv_operation),
    .muldiv_result_o(muldiv_result),
    .ready_o(muldiv_ready)
);

// ==============================================================================
//  BCU
//
bcu BCU(
    .a_i(rs1_data_i),
    .b_i(rs2_data_i),
    .operation_sel_i(branch_operation),
    .compare_result_o(compare_result)
);

// ===============================================================================
//  AGU & Output signals
//
assign mem_addr = rs1_data_i + imm_i;     // The target addr of memory load/store
assign branch_target_addr_o = alu_result; // The target addr of BRANCH, JAL, JALR
assign branch_restore_pc_o = pc_i + 'd4;  // The next PC of instruction, and the
                                          // restore PC if mispredicted branch taken.

assign is_branch_o = is_branch_i | is_jal_i;
assign branch_taken_o = (is_branch_i & compare_result) | is_jal_i | is_jalr_i;
assign branch_misprediction_o = branch_hit_i & (branch_taken_i ^ branch_taken_o);

// ===============================================================================
//  CSR
//
wire [XLEN-1 : 0] csr_inputA = csr_data_i;
wire [XLEN-1 : 0] csr_inputB = operation_sel_i[2] ? {27'b0, csr_imm_i} : rs1_data_i;
reg  [XLEN-1 : 0] csr_update_data;

always @(*)
begin
    case (operation_sel_i[1: 0])
        `CSR_RW:
            csr_update_data = csr_inputB;
        `CSR_RS:
            csr_update_data = csr_inputA | csr_inputB;
        `CSR_RC:
            csr_update_data = csr_inputA & ~csr_inputB;
        default:
            csr_update_data = csr_inputA;
    endcase
end


// ===============================================================================
//  FPU input/output selection
//
reg  [XLEN-1 : 0] inputC;   // f_inputA/B/C: operands fed into the FPIP units.
wire              fpu_stall;

always @(*)
`ifdef ENABLE_FPU
begin
    case (inputC_sel_i)
        3'd0: inputC = rs3_f_data_i;
        3'd1: inputC = {~rs3_f_data_i[31], rs3_f_data_i[30:0]};
        default: inputC = 0;
    endcase
end
`else
    inputC = {XLEN{1'b0}};
`endif

// ===============================================================================
// Execute stage stall signal. If FPU is not enabled, fpu_stall is always 0.
//
assign alu_stall = alu_muldiv_sel_i & !muldiv_ready;
assign stall_from_exe_o = alu_stall | fpu_stall;

// ===============================================================================
//  Output registers to the Memory stage
//
always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i)) // stall has higher priority than flush.
    begin
        rd_input_sel_o <= 0;
        rd_addr_o <= 0;
        rd_we_o <= 0;
        signex_sel_o <= 0;

        we_o <= 0;
        re_o <= 0;
        rs2_data_o <= 0;
        addr_o <= 0;
        dsize_sel_o <= 0;
        is_fencei_o <= 0;
        is_amo_o <= 0;
        amo_type_o <= 0;

        sys_jump_o <= 0;
        sys_jump_mode_o <= 0;
        xcpt_valid_o <= 0;
        xcpt_cause_o <= 0;
        xcpt_tval_o <= 0;
        pc_o <= 0;
        fetch_valid_o <= 0;
        csr_we_o <= 0;
        csr_we_addr_o <= 0;
        csr_we_data_o <= 0;
`ifdef ENABLE_FPU
        rd_fpr_we_o <= 0;
        fp32_load_o <= 0;
`endif
    end
    else if (stall_i || stall_from_exe_o)
    begin
        rd_input_sel_o <= rd_input_sel_o;
        rd_addr_o <= rd_addr_o;
        rd_we_o <= rd_we_o;
        signex_sel_o <= signex_sel_o;

        we_o <= we_o;
        re_o <= re_o;
        rs2_data_o <= rs2_data_o;
        addr_o <= addr_o;
        dsize_sel_o <= dsize_sel_o;
        is_fencei_o <= is_fencei_o;
        is_amo_o <= is_amo_o;
        amo_type_o <= amo_type_o;

        sys_jump_o <= sys_jump_o;
        sys_jump_mode_o <= sys_jump_mode_o;
        xcpt_valid_o <= xcpt_valid_o;
        xcpt_cause_o <= xcpt_cause_o;
        xcpt_tval_o <= xcpt_tval_o;
        pc_o <= pc_o;
        fetch_valid_o <= fetch_valid_o;
        csr_we_o <= csr_we_o;
        csr_we_addr_o <= csr_we_addr_o;
        csr_we_data_o <= csr_we_data_o;
`ifdef ENABLE_FPU
        rd_fpr_we_o <= rd_fpr_we_o;
        fp32_load_o <= fp32_load_o;
`endif
    end
    else
    begin
        rd_input_sel_o <= rd_input_sel_i;
        rd_addr_o <= rd_addr_i;
        rd_we_o <= rd_we_i;
        signex_sel_o <= signex_sel_i;

        we_o <= we_i ;
        re_o <= re_i;
        rs2_data_o <= inputB;
        addr_o  <= mem_addr;
        dsize_sel_o <= dsize_sel_i;
        is_fencei_o <= is_fencei_i;
        is_amo_o <= is_amo_i;
        amo_type_o <= amo_type_i;

        sys_jump_o <= sys_jump_i;
        sys_jump_mode_o <= sys_jump_mode_i;
        xcpt_valid_o <= xcpt_valid_i;
        xcpt_cause_o <= xcpt_cause_i;
        xcpt_tval_o <= xcpt_tval_i;
        pc_o <= pc_i;
        fetch_valid_o <= fetch_valid_i;
        csr_we_o <= csr_we_i;
        csr_we_addr_o <= csr_we_addr_i;
        csr_we_data_o <= csr_update_data;
`ifdef ENABLE_FPU
        rd_fpr_we_o <= rd_fpr_we_i;
        fp32_load_o <= fp32_load_i;
`endif
    end
end

always @(posedge clk_i)
begin
    if (rst_i || (flush_i && !stall_i)) // stall has higher priority than flush.
    begin
        p_data_o <= 0;  // data from processor
    end
    else if (stall_i || stall_from_exe_o)
    begin
        p_data_o <= p_data_o;
    end
    else
    begin
        case (rd_input_sel_i)
            3'b011: p_data_o <= branch_restore_pc_o;
            3'b100: p_data_o <= exe_result;
            3'b101: p_data_o <= csr_data_i;
            default: p_data_o <= 0;
        endcase
    end
end

`ifdef ENABLE_FPU // If FPU is disabled. GCC compiled code must link soft-fp library.
// ===============================================================================
//  FPU calculated result output
//

// ===============================================================================
//  FPIP valid signal
//
wire    AddSub_s_input_valid, Mul_s_input_valid, Div_s_input_valid,
        Sqrt_s_input_valid, CmpLT_s_input_valid, MAddSub_s_input_valid,
        CVT_W_s_input_valid, CVT_s_W_input_valid, CVT_s_WU_input_valid,
        EQ_s_input_valid, LE_s_input_valid;

// FPIP_input_valid: exactly one FP subunit is being issued in this cycle.
// FPIP_output_valid: a previously issued FP subunit returns a result.
wire FPIP_input_valid;
wire FPIP_output_valid;
reg FPIP_input_valid_r;

//=============================================================================
// FPIP dispatch FSM (ipS)
//   ip_IDLE : default, accept a new FP request when FPIP_input_valid_r = 1
//   ip_BUSY : wait until any FPIP asserts its valid output (FPIP_output_valid)
//   ip_WAIT : single cycle delay, prevents skipping the next RV32F/D operation
//=============================================================================

localparam ip_IDLE = 0, ip_BUSY = 1, ip_WAIT = 2;
reg [1:0] ipS, ipS_nxt;

always @(posedge clk_i)
begin
    if (rst_i)
        ipS <= ip_IDLE;
    else
        ipS <= ipS_nxt;
end

always @(*)
begin
    case (ipS)
        ip_IDLE:
            if (FPIP_input_valid_r)
                ipS_nxt = ip_BUSY;
            else
                ipS_nxt = ip_IDLE;
        ip_BUSY:
            if (FPIP_output_valid)
                ipS_nxt = ip_WAIT;
            else
                ipS_nxt = ip_BUSY;
        ip_WAIT:
            ipS_nxt = ip_IDLE;
        default:
            ipS_nxt = ip_IDLE;
    endcase
end

// F extension FPIP signal
wire                f_AddSub_s_valid, f_Mul_s_valid, f_Div_s_valid, f_Sqrt_s_valid,
                    f_CmpLT_s_valid, f_MAddSub_s_valid, f_CVT_W_s_valid, f_CVT_s_W_valid,
                    f_CVT_s_WU_valid, f_EQ_s_valid, f_LE_s_valid;
wire [XLEN-1 : 0]   f_AddSub_s_result;
wire [XLEN-1 : 0]   f_Mul_s_result;
wire [XLEN-1 : 0]   f_Div_s_result;
wire [XLEN-1 : 0]   f_Sqrt_s_result;
wire [7 : 0]        f_CmpLT_s_result;
wire [XLEN-1 : 0]   f_CmpLT_s_answer;
wire [XLEN-1 : 0]   f_MAddSub_s_result;
wire [XLEN-1 : 0]   f_SGNJ_s_result;
wire [2 : 0]        f_SGNJ_s_op;
wire [XLEN-1 : 0]   f_CVT_W_s_result;
wire [XLEN-1 : 0]   f_CVT_s_W_result;
wire [XLEN-1 : 0]   f_CVT_WU_s_result;
wire [XLEN-1 : 0]   f_CVT_s_WU_result;
wire [7 : 0]        f_EQ_s_result;
wire [XLEN-1 : 0]   f_EQ_s_answer;
wire [7 : 0]        f_LT_s_result;
wire [XLEN-1 : 0]   f_LT_s_answer;
wire [7 : 0]        f_LE_s_result;
wire [XLEN-1 : 0]   f_LE_s_answer;
wire [XLEN-1 : 0]   f_CLASS_s_answer;

assign FPIP_input_valid = AddSub_s_input_valid | Mul_s_input_valid | Div_s_input_valid |
                          Sqrt_s_input_valid | CmpLT_s_input_valid | MAddSub_s_input_valid |
                          CVT_W_s_input_valid | CVT_s_W_input_valid | CVT_s_WU_input_valid |
                          EQ_s_input_valid | LE_s_input_valid;
assign FPIP_output_valid = f_AddSub_s_valid | f_Mul_s_valid | f_Div_s_valid | f_Sqrt_s_valid |
                           f_CmpLT_s_valid | f_MAddSub_s_valid | f_CVT_W_s_valid |
                           f_CVT_s_W_valid | f_CVT_s_WU_valid | f_EQ_s_valid | f_LE_s_valid;

always @(posedge clk_i) FPIP_input_valid_r <= FPIP_input_valid;

assign AddSub_s_input_valid = fp_op_i & fp_unit_sel_i == 1  & (ipS_nxt == ip_IDLE);
assign Mul_s_input_valid = fp_op_i & fp_unit_sel_i == 2  & (ipS_nxt == ip_IDLE);
assign Div_s_input_valid = fp_op_i & fp_unit_sel_i == 3  & (ipS_nxt == ip_IDLE);
assign Sqrt_s_input_valid = fp_op_i & fp_unit_sel_i == 4  & (ipS_nxt == ip_IDLE);
assign CmpLT_s_input_valid = fp_op_i & fp_unit_sel_i == 5  & (ipS_nxt == ip_IDLE);
assign MAddSub_s_input_valid = fp_op_i & fp_unit_sel_i == 6  & (ipS_nxt == ip_IDLE);
assign CVT_W_s_input_valid = fp_op_i & fp_unit_sel_i == 7  & (ipS_nxt == ip_IDLE);
assign EQ_s_input_valid = fp_op_i & fp_unit_sel_i == 8  & (ipS_nxt == ip_IDLE);
assign LE_s_input_valid = fp_op_i & fp_unit_sel_i == 9  & (ipS_nxt == ip_IDLE);
assign CVT_s_W_input_valid = fp_op_i & fp_unit_sel_i == 10  & (ipS_nxt == ip_IDLE);
assign CVT_s_WU_input_valid = fp_op_i & fp_unit_sel_i == 11  & (ipS_nxt == ip_IDLE);

assign f_CmpLT_s_answer = (fp_func_sel_i == 6) ? (f_CmpLT_s_result ? inputA[31:0] : inputB[31:0])
                    : (f_CmpLT_s_result ? inputB[31:0] : inputA[31:0]);
assign f_SGNJ_s_op = (fp_func_sel_i == 12) ? 1 : (fp_func_sel_i == 13) ? 2 : (fp_func_sel_i == 14) ? 3 : 0;
assign f_EQ_s_answer = {24'd0, f_EQ_s_result};
assign f_LE_s_answer = {24'd0, f_LE_s_result};
assign f_LT_s_answer = {24'd0, f_CmpLT_s_result};
assign f_CLASS_s_answer = (inputA[31:0] == {1'b1, 8'd255, 23'd0}) ? 32'h00000001
                        : (inputA[31:0] == {1'b1, 8'd0, 23'd0}) ? 32'h00000008
                        : (inputA[31:0] == {1'b0, 8'd0, 23'd0}) ? 32'h00000010
                        : (inputA[31:0] == {1'b0, 8'd255, 23'd0}) ? 32'h00000080
                        : (inputA[31 : 23] == {1'b0, 8'd0}) ? 32'h00000020
                        : (inputA[31 : 23] == {1'b1, 8'd0}) ? 32'h00000004
                        : (inputA[30 : 22] == {8'd255, 1'b0}) ? 32'h00000100
                        : (inputA[30 : 22] == {8'd255, 1'b1}) ? 32'h00000200
                        : (inputA[31] == 1'b1) ? 32'h00000002 : 32'h00000040;

assign f_CVT_WU_s_result = (f_CVT_W_s_result[31] == 0) ? f_CVT_W_s_result : 32'd0;

//=============================================================================
// FPIP 
//

FP_Add_Sub_S FP_Add_Sub_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(AddSub_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(AddSub_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),

    .m_axis_result_tdata(f_AddSub_s_result),
    .m_axis_result_tvalid(f_AddSub_s_valid)
);

FP_Mul_S FP_Mul_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Mul_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(Mul_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),
    
    .m_axis_result_tdata(f_Mul_s_result),
    .m_axis_result_tvalid(f_Mul_s_valid)
);

FP_Div_S FP_Div_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Div_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(Div_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),
    
    .m_axis_result_tdata(f_Div_s_result),
    .m_axis_result_tvalid(f_Div_s_valid)
);

FP_Sqrt_S FP_Sqrt_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(Sqrt_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .m_axis_result_tdata(f_Sqrt_s_result),
    .m_axis_result_tvalid(f_Sqrt_s_valid)
);

FP_CmpLT_S FP_CmpLT_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(CmpLT_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(CmpLT_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),
    
    .m_axis_result_tdata(f_CmpLT_s_result),
    .m_axis_result_tvalid(f_CmpLT_s_valid)
);

FP_MAddSub_S FP_MAddSub_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(MAddSub_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(MAddSub_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),
    
    .s_axis_c_tvalid(MAddSub_s_input_valid),
    .s_axis_c_tdata(inputC[31:0]),
    
    .m_axis_result_tdata(f_MAddSub_s_result),
    .m_axis_result_tvalid(f_MAddSub_s_valid)
);

FP_CVT_W_S FP_CVT_W_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_W_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .m_axis_result_tdata(f_CVT_W_s_result),
    .m_axis_result_tvalid(f_CVT_W_s_valid)
);

FP_EQ_S FP_EQ_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(EQ_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(EQ_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),

    .m_axis_result_tdata(f_EQ_s_result),
    .m_axis_result_tvalid(f_EQ_s_valid)
);

FP_CVT_S_W FP_CVT_S_W(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_s_W_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_s_W_result),
    .m_axis_result_tvalid(f_CVT_s_W_valid)
);

FP_CVT_S_WU FP_CVT_S_WU(
    .aclk(clk_i),

    .s_axis_a_tvalid(CVT_s_WU_input_valid),
    .s_axis_a_tdata(inputA),

    .m_axis_result_tdata(f_CVT_s_WU_result),
    .m_axis_result_tvalid(f_CVT_s_WU_valid)
);

FP_LE_S FP_LE_S(
    .aclk(clk_i),

    .s_axis_a_tvalid(LE_s_input_valid),
    .s_axis_a_tdata(inputA[31:0]),

    .s_axis_b_tvalid(LE_s_input_valid),
    .s_axis_b_tdata(inputB[31:0]),

    .m_axis_result_tdata(f_LE_s_result),
    .m_axis_result_tvalid(f_LE_s_valid)
);

assign f_SGNJ_s_result = (f_SGNJ_s_op == 1) ? {inputB[31], inputA[30 : 0]}
                        : (f_SGNJ_s_op == 2) ? {~inputB[31], inputA[30 : 0]}
                        : (f_SGNJ_s_op == 3) ? {inputA[31] ^ inputB[31], inputA[30 : 0]} : 0;

assign exe_result = fp_op_i ? (
                fp_unit_sel_i == 1 ? f_AddSub_s_result
                : fp_unit_sel_i == 2 ? f_Mul_s_result
                : fp_unit_sel_i == 3 ? f_Div_s_result
                : fp_unit_sel_i == 4 ? f_Sqrt_s_result
                : fp_func_sel_i == 6 | fp_func_sel_i == 7 ? f_CmpLT_s_answer
                : fp_unit_sel_i == 6 ? f_MAddSub_s_result
                : fp_unit_sel_i == 10 ? f_CVT_s_W_result
                : fp_unit_sel_i == 11 ? f_CVT_s_WU_result
                : fp_func_sel_i == 18 ? inputA
                : (fp_func_sel_i == 12 | fp_func_sel_i == 13 | fp_func_sel_i == 14) ? f_SGNJ_s_result
                : fp_func_sel_i == 15 ? f_CVT_W_s_result
                : fp_func_sel_i == 16 ? f_CVT_WU_s_result 
                : fp_func_sel_i == 17 ? inputA[31:0]
                : fp_func_sel_i == 19 ? f_EQ_s_answer
                : fp_func_sel_i == 20 ? f_LT_s_answer
                : fp_func_sel_i == 21 ? f_LE_s_answer
                : fp_func_sel_i == 22 ? f_CLASS_s_answer
                : 0)
                : alu_muldiv_sel_i ? muldiv_result : alu_result;

assign fpu_stall = (ipS_nxt == ip_BUSY) | FPIP_input_valid;

`else

// ===============================================================================
//  Floating point instructions are disabled so fpu_stall is always 0.
//
assign exe_result = alu_muldiv_sel_i ? muldiv_result : alu_result;
assign fpu_stall = 0;

`endif // ENABLE_FPU
endmodule

