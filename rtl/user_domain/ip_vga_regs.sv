// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module ip_vga_regs
  import ip_vga_regs_pkg::*;
#(
    parameter int unsigned FontSramBase = 12'h100,
    parameter type         obi_req_t    = logic,
    parameter type         obi_rsp_t    = logic
) (
    input  logic                  clk_i,
    input  logic                  rst_ni,
    input  obi_req_t              obi_req_i,
    output obi_rsp_t              obi_rsp_o,
    // To hardware
    output ip_vga_reg2hw_t        reg2hw_o,
    // Font SRAM write (combinatorial, registered in consumer)
    output logic                  font_wr_req_o,
    output logic           [ 7:0] font_wr_addr_o,
    output logic           [63:0] font_wr_data_o,
    output logic           [ 7:0] font_wr_be_o
);
  // read-write registers
  logic [31:0] tb_addr_d, tb_addr_q;
  logic [7:0] clk_div_d, clk_div_q;
  logic vga_en_d, vga_en_q;
  logic fsm_en_d, fsm_en_q;
  logic vga_hsync_pol_d, vga_hsync_pol_q;
  logic vga_vsync_pol_d, vga_vsync_pol_q;
  logic [7:0] vga_line_width_d, vga_line_width_q;
  logic [7:0] vga_line_height_d, vga_line_height_q;

  logic [7:0] vga_horz_front_porch_d, vga_horz_front_porch_q;
  logic [7:0] vga_horz_sync_d, vga_horz_sync_q;
  logic [7:0] vga_horz_back_porch_d, vga_horz_back_porch_q;
  logic [7:0] vga_vert_front_porch_d, vga_vert_front_porch_q;
  logic [7:0] vga_vert_sync_d, vga_vert_sync_q;
  logic [7:0] vga_vert_back_porch_d, vga_vert_back_porch_q;

  `FF(tb_addr_q, tb_addr_d, '0, clk_i, rst_ni)
  `FF(clk_div_q, clk_div_d, 8'h2, clk_i, rst_ni)
  `FF(vga_en_q, vga_en_d, 0, clk_i, rst_ni)
  `FF(fsm_en_q, fsm_en_d, 0, clk_i, rst_ni)
  `FF(vga_hsync_pol_q, vga_hsync_pol_d, 1, clk_i, rst_ni)
  `FF(vga_vsync_pol_q, vga_vsync_pol_d, 1, clk_i, rst_ni)
  `FF(vga_line_width_q, vga_line_width_d, 80, clk_i, rst_ni)
  `FF(vga_line_height_q, vga_line_height_d, 25, clk_i, rst_ni)
  `FF(vga_horz_front_porch_q, vga_horz_front_porch_d, 'h01, clk_i, rst_ni)
  `FF(vga_horz_sync_q, vga_horz_sync_d, 'h01, clk_i, rst_ni)
  `FF(vga_horz_back_porch_q, vga_horz_back_porch_d, 'h01, clk_i, rst_ni)
  `FF(vga_vert_front_porch_q, vga_vert_front_porch_d, 'h01, clk_i, rst_ni)
  `FF(vga_vert_sync_q, vga_vert_sync_d, 'h01, clk_i, rst_ni)
  `FF(vga_vert_back_porch_q, vga_vert_back_porch_d, 'h01, clk_i, rst_ni)

  // OBI handling, A-phase fields needed in the R-phase
  logic                              req_q;
  logic                              we_q;
  logic [$bits(obi_req_i.a.aid)-1:0] id_q;
  logic [          IntAddrWidth-1:2] addr_q;  // word-aligned address bits only

  `FF(req_q, obi_req_i.req, '0, clk_i, rst_ni)
  `FF(we_q, obi_req_i.a.we, '0, clk_i, rst_ni)
  `FF(id_q, obi_req_i.a.aid, '0, clk_i, rst_ni)
  `FF(addr_q, obi_req_i.a.addr[IntAddrWidth-1:2], '0, clk_i, rst_ni)

  // byte-enable mask: expands each BE bit to a full byte for masked writes
  logic [31:0] be_mask;
  for (genvar i = 0; unsigned'(i) < 32 / 8; ++i) begin : gen_write_mask
    assign be_mask[8*i+:8] = {8{obi_req_i.a.be[i]}};
  end

  // Font SRAM write decode (combinatorial from OBI address phase)
  // NOTE: Font word size is 64b, OBI word size is 32b
  localparam int unsigned FontSramSize = 2048;
  logic font_sram_acc;
  logic [$clog2(FontSramSize)-1:0] font_rel_addr;
  assign font_sram_acc = obi_req_i.req &&
      obi_req_i.a.addr[11:0] >= FontSramBase &&
      obi_req_i.a.addr[11:0] <  FontSramBase + FontSramSize;
  assign font_rel_addr = obi_req_i.a.addr[11:0] - FontSramBase;

  // NOTE: currently do not allow write when fsm_en to avoid conflict with fetcher
  assign font_wr_req_o = !fsm_en_q & font_sram_acc & obi_req_i.a.we;
  assign font_wr_addr_o = font_rel_addr[$clog2(FontSramSize)-1:3];
  assign font_wr_data_o = font_rel_addr[2] ?
      {obi_req_i.a.wdata, 32'b0} : {32'b0, obi_req_i.a.wdata};
  assign font_wr_be_o = font_rel_addr[2] ? {obi_req_i.a.be, 4'b0} : {4'b0, obi_req_i.a.be};

  // Registered font SRAM access for response phase
  logic font_sram_q;
  `FF(font_sram_q, font_sram_acc, '0, clk_i, rst_ni)

  assign reg2hw_o.tb_addr = tb_addr_q;
  assign reg2hw_o.clk_div = clk_div_q;
  assign reg2hw_o.vga_en = vga_en_q;
  assign reg2hw_o.fsm_en = fsm_en_q;
  assign reg2hw_o.vga_hsync_pol = vga_hsync_pol_q;
  assign reg2hw_o.vga_vsync_pol = vga_vsync_pol_q;
  assign reg2hw_o.vga_line_width = vga_line_width_q;
  assign reg2hw_o.vga_line_height = vga_line_height_q;

  assign reg2hw_o.vga_horz_front_porch = vga_horz_front_porch_q;
  assign reg2hw_o.vga_horz_sync = vga_horz_sync_q;
  assign reg2hw_o.vga_horz_back_porch = vga_horz_back_porch_q;

  assign reg2hw_o.vga_vert_front_porch = vga_vert_front_porch_q;
  assign reg2hw_o.vga_vert_sync = vga_vert_sync_q;
  assign reg2hw_o.vga_vert_back_porch = vga_vert_back_porch_q;


  // Address phase: update writable registers
  always_comb begin : write_fsm
    tb_addr_d = tb_addr_q;
    clk_div_d = clk_div_q;
    vga_en_d = vga_en_q;
    fsm_en_d = fsm_en_q;
    vga_hsync_pol_d = vga_hsync_pol_q;
    vga_vsync_pol_d = vga_vsync_pol_q;
    vga_line_width_d = vga_line_width_q;
    vga_line_height_d = vga_line_height_q;
    vga_horz_front_porch_d = vga_horz_front_porch_q;
    vga_horz_sync_d = vga_horz_sync_q;
    vga_horz_back_porch_d = vga_horz_back_porch_q;
    vga_vert_front_porch_d = vga_vert_front_porch_q;
    vga_vert_sync_d = vga_vert_sync_q;
    vga_vert_back_porch_d = vga_vert_back_porch_q;

    if (obi_req_i.req && obi_req_i.a.we && !font_sram_acc) begin
      unique case ({
        obi_req_i.a.addr[IntAddrWidth-1:2], 2'b00
      })
        TB_ADDR_OFFSET: tb_addr_d = obi_req_i.a.wdata & be_mask;
        CLK_DIV_OFFSET: clk_div_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_EN_OFFSET: vga_en_d = obi_req_i.a.wdata[0] & be_mask[0];
        FSM_EN_OFFSET: fsm_en_d = obi_req_i.a.wdata[0] & be_mask[0];
        VGA_HSYNC_POL_OFFSET: vga_hsync_pol_d = obi_req_i.a.wdata[0] & be_mask[0];
        VGA_VSYNC_POL_OFFSET: vga_vsync_pol_d = obi_req_i.a.wdata[0] & be_mask[0];
        VGA_LINE_WIDTH_OFFSET: vga_line_width_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_LINE_HEIGHT_OFFSET: vga_line_height_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_HORZ_FRONT_PORCH_OFFSET: vga_horz_front_porch_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_HORZ_SYNC_OFFSET: vga_horz_sync_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_HORZ_BACK_PORCH_OFFSET: vga_horz_back_porch_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_VERT_FRONT_PORCH_OFFSET: vga_vert_front_porch_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_VERT_SYNC_OFFSET: vga_vert_sync_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_VERT_BACK_PORCH_OFFSET: vga_vert_back_porch_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];

        default: ;  // invalid address: no write, error signalled in R phase
      endcase
    end
  end

  // Response phase: send back read data or acknowledge write
  always_comb begin : obi_response
    obi_rsp_o        = '0;
    obi_rsp_o.gnt    = 1'b1;
    obi_rsp_o.rvalid = req_q;
    obi_rsp_o.r.rid  = id_q;

    if (req_q) begin
      if (font_sram_q) begin
        if (!we_q) begin
          // font SRAM do not allow read, reserved read port for ip_vga
          obi_rsp_o.r.rdata = '0;
          obi_rsp_o.r.err   = 1'b1;
        end
      end else if (!we_q) begin
        unique case ({
          addr_q, 2'b00
        })
          TB_ADDR_OFFSET: obi_rsp_o.r.rdata = tb_addr_q;
          CLK_DIV_OFFSET: obi_rsp_o.r.rdata = {24'h0, clk_div_q};
          VGA_EN_OFFSET: obi_rsp_o.r.rdata = {31'h0, vga_en_q};
          FSM_EN_OFFSET: obi_rsp_o.r.rdata = {31'h0, fsm_en_q};
          VGA_HSYNC_POL_OFFSET: obi_rsp_o.r.rdata = {31'h0, vga_hsync_pol_q};
          VGA_VSYNC_POL_OFFSET: obi_rsp_o.r.rdata = {31'h0, vga_vsync_pol_q};
          VGA_LINE_WIDTH_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_line_width_q};
          VGA_LINE_HEIGHT_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_line_height_q};
          VGA_HORZ_FRONT_PORCH_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_horz_front_porch_q};
          VGA_HORZ_SYNC_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_horz_sync_q};
          VGA_HORZ_BACK_PORCH_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_horz_back_porch_q};
          VGA_VERT_FRONT_PORCH_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_vert_front_porch_q};
          VGA_VERT_SYNC_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_vert_sync_q};
          VGA_VERT_BACK_PORCH_OFFSET: obi_rsp_o.r.rdata = {24'h0, vga_vert_back_porch_q};
          default: begin
            obi_rsp_o.r.rdata = 32'hBADCAB1E;
            obi_rsp_o.r.err   = 1'b1;
          end
        endcase
      end else begin
        unique case ({
          addr_q, 2'b00
        })
          TB_ADDR_OFFSET, CLK_DIV_OFFSET, VGA_EN_OFFSET, FSM_EN_OFFSET,
          VGA_HSYNC_POL_OFFSET, VGA_VSYNC_POL_OFFSET, VGA_LINE_WIDTH_OFFSET, VGA_LINE_HEIGHT_OFFSET, 
          VGA_HORZ_FRONT_PORCH_OFFSET, VGA_HORZ_SYNC_OFFSET, VGA_HORZ_BACK_PORCH_OFFSET,
          VGA_VERT_FRONT_PORCH_OFFSET, VGA_VERT_SYNC_OFFSET, VGA_VERT_BACK_PORCH_OFFSET:
          ;  // valid write, no error
          default: obi_rsp_o.r.err = 1'b1;
        endcase
      end
    end
  end

endmodule
