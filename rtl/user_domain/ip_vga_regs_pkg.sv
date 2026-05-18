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
    logic vga_en; // for enable IP
    logic fsm_en; // for disable FSM to allow font write but still output stale VGA
    logic vga_hsync_pol;
    logic vga_vsync_pol;
    logic [7:0] vga_line_width;
    logic [7:0] vga_line_height;

    logic [7:0] vga_horz_front_porch;
    logic [7:0] vga_horz_sync;
    logic [7:0] vga_horz_back_porch;

    logic [7:0] vga_vert_front_porch;
    logic [7:0] vga_vert_sync;
    logic [7:0] vga_vert_back_porch;
  } ip_vga_reg2hw_t;

  // Internal address width. 5 bits covers offsets 0x00–0x1C (8 word-aligned registers).
  localparam int unsigned IntAddrWidth = $clog2(13) + 2;

  // Register offsets
  parameter logic [IntAddrWidth-1:0] TB_ADDR_OFFSET = 6'h00;
  parameter logic [IntAddrWidth-1:0] CLK_DIV_OFFSET = 6'h04;
  parameter logic [IntAddrWidth-1:0] VGA_EN_OFFSET = 6'h08;
  parameter logic [IntAddrWidth-1:0] FSM_EN_OFFSET = 6'h0C;
  parameter logic [IntAddrWidth-1:0] VGA_HSYNC_POL_OFFSET = 6'h10;
  parameter logic [IntAddrWidth-1:0] VGA_VSYNC_POL_OFFSET = 6'h14;
  parameter logic [IntAddrWidth-1:0] VGA_LINE_WIDTH_OFFSET = 6'h18;
  parameter logic [IntAddrWidth-1:0] VGA_LINE_HEIGHT_OFFSET = 6'h1C;
  parameter logic [IntAddrWidth-1:0] VGA_HORZ_FRONT_PORCH_OFFSET = 6'h20;
  parameter logic [IntAddrWidth-1:0] VGA_HORZ_SYNC_OFFSET = 6'h24;
  parameter logic [IntAddrWidth-1:0] VGA_HORZ_BACK_PORCH_OFFSET = 6'h28;
  parameter logic [IntAddrWidth-1:0] VGA_VERT_FRONT_PORCH_OFFSET = 6'h2C;
  parameter logic [IntAddrWidth-1:0] VGA_VERT_SYNC_OFFSET = 6'h30;
  parameter logic [IntAddrWidth-1:0] VGA_VERT_BACK_PORCH_OFFSET = 6'h34;

endpackage
