// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

package ip_vga_regs_pkg;
  typedef struct packed {
    logic [31:0] tb_addr;
    logic [7:0] clk_div;
    logic vga_en;
  } ip_vga_reg2hw_t;

  // Internal address width. 5 bits covers offsets 0x00–0x1C (8 word-aligned registers).
  localparam int unsigned IntAddrWidth = $clog2(8) + 2;

  // Register offsets
  parameter logic [IntAddrWidth-1:0] TB_ADDR_OFFSET      = 5'h00;
  parameter logic [IntAddrWidth-1:0] CLK_DIV_OFFSET      = 5'h04;
  parameter logic [IntAddrWidth-1:0] VGA_EN_OFFSET       = 5'h08;

endpackage
