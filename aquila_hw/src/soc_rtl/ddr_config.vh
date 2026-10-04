`timescale 1ns / 1ps
// =============================================================================
//  Program : ddr_config.vh
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

// The target board can be ARTY, AXKU5, QMCore, Genesys2, K7BaseC, or KC705,
// the MACRO is defined globally in the TCL script when the project was created

`ifdef ARTY
    `define DDR3
    `define DRAM_WIDTH_16
    `define DRAM_BLK_128
    `define UIADR 28              // DRAM chip addr width
    `define DRAMA 14              // DRAM chip addr width
    `define DRAMD 16              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  128             // MIG controller user logic data width
    `define DQSP  2               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`elsif QMCore
    `define DDR3
    `define DRAM_WIDTH_16
    `define DRAM_BLK_128
    `define UIADR 28              // DRAM chip addr width
    `define DRAMA 14              // DRAM chip addr width
    `define DRAMD 16              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  128             // MIG controller user logic data width
    `define DQSP  2               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`elsif AXKU5
    `define DDR4
    `define DRAM_WIDTH_32
    `define DRAM_BLK_256
    `define UIADR 29              // DRAM chip addr width
    `define DRAMA 17              // DRAM chip addr width
    `define DRAMD 32              // DRAM chip bus width
    `define BA    2               // DRAM bank addr width
    `define WDFP  256             // MIG controller user logic data width
    `define DQSP  4               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`elsif PZKU060
    `define DDR4
    `define DRAM_WIDTH_64
    `define DRAM_BLK_512
    `define UIADR 29              // MIG controller user logic addr width
    `define DRAMA 17              // DRAM chip addr width
    `define DRAMD 64              // DRAM chip bus width
    `define BA    2               // Number of DRAM banks
    `define WDFP  512             // MIG controller user logic data width
    `define DQSP  8               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`elsif K7BaseC
    `define DDR3
    `define DRAM_WIDTH_32
    `define DRAM_BLK_256
    `define UIADR 29              // DRAM chip addr width
    `define DRAMA 15              // DRAM chip addr width
    `define DRAMD 32              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  256             // MIG controller user logic data width
    `define DQSP  4               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`elsif Genesys2
    `define DDR3
    `define DRAM_WIDTH_32
    `define DRAM_BLK_256
    `define UIADR 29              // DRAM chip addr width
    `define DRAMA 15              // DRAM chip addr width
    `define DRAMD 32              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  256             // MIG controller user logic data width
    `define DQSP  4               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
`else // KC705
    `define DDR3
    `define DRAM_WIDTH_64
    `define DRAM_BLK_512
    `define UIADR 28              // DRAM chip addr width
    `define DRAMA 14              // DRAM chip addr width
    `define DRAMD 64              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  512             // MIG controller user logic data width
    `define DQSP  8               // MIG DQS parameter
    `define USRP  5               // # of user buttons & LEDs
`endif
