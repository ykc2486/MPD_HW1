`timescale 1ns / 1ps 
// =============================================================================
//  Program : aquila_config.vh
//  Author  : Chun-Jen Tsai
//  Date    : Aug/23/2022
// -----------------------------------------------------------------------------
//  Description:
//  This is the configuration parameters for the Aquila core.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2022 - ,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity (NYCU)
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

//==============================================================================================
// Parameters and Integers
//==============================================================================================

// Tightly-Coupled Memory Size
`define TCM_SIZE_IN_WORDS 16384   // 64KB

// Cache parameters are ignored unless the DDRx memory is enabled in
//   the TCL build script, where the cache line size 'CLP' is defined.
`define ICACHE_SIZE 8  // Instruction cache size in KB
`define DCACHE_SIZE 8  // Data cache size in KB

// Branch Prediction
`define ENABLE_BRANCH_PREDICTION

// Atomic Unit
`define ENABLE_ATOMIC_UNIT

// Muldiv Integer multiplier
`define ENABLE_FAST_MULTIPLY

// Fetch
`define NOP 32'h00000013

// SIM_FNAME defines the RISC-V program path of an ELF file for simulation.
`define SIM_FNAME "C:/MPC/dhry.elf"