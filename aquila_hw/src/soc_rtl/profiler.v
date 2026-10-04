//BSD 3-Clause License

//Copyright (c) 2026, ykc2486

`timescale 1ns / 1ps

module profiler (
    input  wire        clk,
    input  wire        rst,

    // Profiling signals
    input  wire [31:0] pc,
    input  wire        is_mem_cycle,

    // MMIO interface
    input  wire        mmio_en,
    input  wire        mmio_we,
    input  wire [31:0] mmio_addr,
    input  wire [31:0] mmio_wdata,
    output reg  [31:0] mmio_rdata,
    output wire        mmio_ready,

    // Debug outputs
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

    // Function address ranges
    reg [31:0] f0_start;
    reg [31:0] f0_end;
    reg [31:0] f1_start;
    reg [31:0] f1_end;
    reg [31:0] f2_start;
    reg [31:0] f2_end;
    reg [31:0] f3_start;
    reg [31:0] f3_end;
    reg [31:0] f4_start;
    reg [31:0] f4_end;

    // MMIO region is aligned to 256 bytes,
    // so the lowest 8 bits are the register offset.
    wire [7:0] offset = mmio_addr[7:0];

    wire in_f0 = (pc >= f0_start && pc < f0_end);
    wire in_f1 = (pc >= f1_start && pc < f1_end);
    wire in_f2 = (pc >= f2_start && pc < f2_end);
    wire in_f3 = (pc >= f3_start && pc < f3_end);
    wire in_f4 = (pc >= f4_start && pc < f4_end);

    // This profiler always responds immediately when selected.
    reg mmio_ready_reg;

    assign mmio_ready = mmio_ready_reg;
    
    always @(posedge clk) begin
        if (rst)
            mmio_ready_reg <= 1'b0;
        else
            mmio_ready_reg <= mmio_en;
    end

    // -------------------------------------------------------------------------
    // Counter and MMIO write logic
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            active       <= 1'b0;

            total_cycles <= 32'd0;

            f0_total_cyc <= 32'd0;
            f0_mem_cyc   <= 32'd0;
            f1_total_cyc <= 32'd0;
            f1_mem_cyc   <= 32'd0;
            f2_total_cyc <= 32'd0;
            f2_mem_cyc   <= 32'd0;
            f3_total_cyc <= 32'd0;
            f3_mem_cyc   <= 32'd0;
            f4_total_cyc <= 32'd0;
            f4_mem_cyc   <= 32'd0;

            f0_start <= 32'd0;
            f0_end   <= 32'd0;
            f1_start <= 32'd0;
            f1_end   <= 32'd0;
            f2_start <= 32'd0;
            f2_end   <= 32'd0;
            f3_start <= 32'd0;
            f3_end   <= 32'd0;
            f4_start <= 32'd0;
            f4_end   <= 32'd0;
        end
        else begin

            // MMIO writes
            if (mmio_en && mmio_we) begin
                case (offset)

                    // Control register
                    // bit 0 = enable
                    // bit 1 = clear
                    8'h00: begin
                        active <= mmio_wdata[0];

                        if (mmio_wdata[1]) begin
                            total_cycles <= 32'd0;

                            f0_total_cyc <= 32'd0;
                            f0_mem_cyc   <= 32'd0;
                            f1_total_cyc <= 32'd0;
                            f1_mem_cyc   <= 32'd0;
                            f2_total_cyc <= 32'd0;
                            f2_mem_cyc   <= 32'd0;
                            f3_total_cyc <= 32'd0;
                            f3_mem_cyc   <= 32'd0;
                            f4_total_cyc <= 32'd0;
                            f4_mem_cyc   <= 32'd0;
                        end
                    end

                    // Channel 0
                    8'h10: f0_start <= mmio_wdata;
                    8'h14: f0_end   <= mmio_wdata;

                    // Channel 1
                    8'h20: f1_start <= mmio_wdata;
                    8'h24: f1_end   <= mmio_wdata;

                    // Channel 2
                    8'h30: f2_start <= mmio_wdata;
                    8'h34: f2_end   <= mmio_wdata;

                    // Channel 3
                    8'h40: f3_start <= mmio_wdata;
                    8'h44: f3_end   <= mmio_wdata;

                    // Channel 4
                    8'h50: f4_start <= mmio_wdata;
                    8'h54: f4_end   <= mmio_wdata;

                    default: begin
                    end
                endcase
            end

            // Do not count during a control-register write.
            else if (active) begin
                total_cycles <= total_cycles + 1'b1;

                if (in_f0) begin
                    f0_total_cyc <= f0_total_cyc + 1'b1;

                    if (is_mem_cycle)
                        f0_mem_cyc <= f0_mem_cyc + 1'b1;
                end

                if (in_f1) begin
                    f1_total_cyc <= f1_total_cyc + 1'b1;

                    if (is_mem_cycle)
                        f1_mem_cyc <= f1_mem_cyc + 1'b1;
                end

                if (in_f2) begin
                    f2_total_cyc <= f2_total_cyc + 1'b1;

                    if (is_mem_cycle)
                        f2_mem_cyc <= f2_mem_cyc + 1'b1;
                end

                if (in_f3) begin
                    f3_total_cyc <= f3_total_cyc + 1'b1;

                    if (is_mem_cycle)
                        f3_mem_cyc <= f3_mem_cyc + 1'b1;
                end

                if (in_f4) begin
                    f4_total_cyc <= f4_total_cyc + 1'b1;

                    if (is_mem_cycle)
                        f4_mem_cyc <= f4_mem_cyc + 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // MMIO read logic
    // -------------------------------------------------------------------------
    always @(*) begin
        case (offset)
                8'h00: mmio_rdata = {31'd0, active};
                8'h04: mmio_rdata = total_cycles;
        
                8'h10: mmio_rdata = f0_start;
                8'h14: mmio_rdata = f0_end;
                8'h18: mmio_rdata = f0_total_cyc;
                8'h1C: mmio_rdata = f0_mem_cyc;
        
                8'h20: mmio_rdata = f1_start;
                8'h24: mmio_rdata = f1_end;
                8'h28: mmio_rdata = f1_total_cyc;
                8'h2C: mmio_rdata = f1_mem_cyc;
        
                8'h30: mmio_rdata = f2_start;
                8'h34: mmio_rdata = f2_end;
                8'h38: mmio_rdata = f2_total_cyc;
                8'h3C: mmio_rdata = f2_mem_cyc;
        
                8'h40: mmio_rdata = f3_start;
                8'h44: mmio_rdata = f3_end;
                8'h48: mmio_rdata = f3_total_cyc;
                8'h4C: mmio_rdata = f3_mem_cyc;
        
                8'h50: mmio_rdata = f4_start;
                8'h54: mmio_rdata = f4_end;
                8'h58: mmio_rdata = f4_total_cyc;
                8'h5C: mmio_rdata = f4_mem_cyc;

            default: mmio_rdata = 32'd0;
        endcase
    end

endmodule