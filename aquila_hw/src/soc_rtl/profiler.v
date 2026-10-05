`timescale 1ns / 1ps

module profiler #(
    parameter MAIN_START  = 32'h000010c0,
    parameter MAIN_RETURN = 32'h00003764,  

    parameter F0_START = 32'h00001af8, parameter F0_END = 32'h00001c28, // crcu8
    parameter F1_START = 32'h00002278, parameter F1_END = 32'h000022c4, // core_list_find
    parameter F2_START = 32'h000022c4, parameter F2_END = 32'h000022e8, // core_list_reverse
    parameter F3_START = 32'h00002be0, parameter F3_END = 32'h00002c94, // matrix_mul_matrix_bitextract
    parameter F4_START = 32'h000031e8, parameter F4_END = 32'h00003510  // core_state_transition
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc,            
    input  wire        is_mem_cycle,  

    // ILA 觀測暫存器
    (* mark_debug = "true", keep = "true" *) output reg [31:0] total_cycles,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f0_total_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f0_mem_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f1_total_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f1_mem_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f2_total_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f2_mem_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f3_total_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f3_mem_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f4_total_cyc,
    (* mark_debug = "true", keep = "true" *) output reg [31:0] f4_mem_cyc
);

    (* mark_debug = "true", keep = "true" *) reg active;

    wire in_f0 = (pc >= F0_START && pc < F0_END);
    wire in_f1 = (pc >= F1_START && pc < F1_END);
    wire in_f2 = (pc >= F2_START && pc < F2_END);
    wire in_f3 = (pc >= F3_START && pc < F3_END);
    wire in_f4 = (pc >= F4_START && pc < F4_END);

    always @(posedge clk) begin
        if (rst) begin
            active       <= 1'b0;
            total_cycles <= 32'd0;
            f0_total_cyc <= 32'd0; f0_mem_cyc <= 32'd0;
            f1_total_cyc <= 32'd0; f1_mem_cyc <= 32'd0;
            f2_total_cyc <= 32'd0; f2_mem_cyc <= 32'd0;
            f3_total_cyc <= 32'd0; f3_mem_cyc <= 32'd0;
            f4_total_cyc <= 32'd0; f4_mem_cyc <= 32'd0;
        end else begin
            if (pc == MAIN_START && !active) begin
                active <= 1'b1;
            end
            else if (pc == MAIN_RETURN && active) begin
                active <= 1'b0;
            end

            // 計時累加
            if (active) begin
                total_cycles <= total_cycles + 1'b1;

                if (in_f0) begin
                    f0_total_cyc <= f0_total_cyc + 1'b1;
                    if (is_mem_cycle) f0_mem_cyc <= f0_mem_cyc + 1'b1;
                end
                if (in_f1) begin
                    f1_total_cyc <= f1_total_cyc + 1'b1;
                    if (is_mem_cycle) f1_mem_cyc <= f1_mem_cyc + 1'b1;
                end
                if (in_f2) begin
                    f2_total_cyc <= f2_total_cyc + 1'b1;
                    if (is_mem_cycle) f2_mem_cyc <= f2_mem_cyc + 1'b1;
                end
                if (in_f3) begin
                    f3_total_cyc <= f3_total_cyc + 1'b1;
                    if (is_mem_cycle) f3_mem_cyc <= f3_mem_cyc + 1'b1;
                end
                if (in_f4) begin
                    f4_total_cyc <= f4_total_cyc + 1'b1;
                    if (is_mem_cycle) f4_mem_cyc <= f4_mem_cyc + 1'b1;
                end
            end
        end
    end

endmodule