// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module ip_vga_regs import ip_vga_regs_pkg::*; #(
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
) (
    input  logic            clk_i,
    input  logic            rst_ni,
    input  obi_req_t        obi_req_i,
    output obi_rsp_t        obi_rsp_o,
    // To hardware
    output ip_vga_reg2hw_t reg2hw_o
);
  // read-write registers
  logic [31:0] tb_addr_d, tb_addr_q;
  logic [7:0] clk_div_d, clk_div_q;
  logic vga_en_d, vga_en_q;

  `FF(tb_addr_q, tb_addr_d, '0, clk_i, rst_ni)
  `FF(clk_div_q, clk_div_d, 8'h2, clk_i, rst_ni)
  `FF(vga_en_q, vga_en_d, 0, clk_i, rst_ni)

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

  assign reg2hw_o.tb_addr = tb_addr_q;
  assign reg2hw_o.clk_div = clk_div_q;
  assign reg2hw_o.vga_en  = vga_en_q;

  // Address phase: update writable registers
  always_comb begin : write_fsm
    tb_addr_d = tb_addr_q;
    clk_div_d = clk_div_q;
    vga_en_d  = vga_en_q;

    if (obi_req_i.req && obi_req_i.a.we) begin
      unique case ({
        obi_req_i.a.addr[IntAddrWidth-1:2], 2'b00
      })
        TB_ADDR_OFFSET: tb_addr_d = obi_req_i.a.wdata & be_mask;
        CLK_DIV_OFFSET: clk_div_d = obi_req_i.a.wdata[7:0] & be_mask[7:0];
        VGA_EN_OFFSET:  vga_en_d = obi_req_i.a.wdata[0] & be_mask[0];
        default:        ;  // invalid address: no write, error signalled in R phase
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
      if (!we_q) begin
        unique case ({
          addr_q, 2'b00
        })
          TB_ADDR_OFFSET: obi_rsp_o.r.rdata = tb_addr_q;
          CLK_DIV_OFFSET: obi_rsp_o.r.rdata = {24'h0, clk_div_q};
          VGA_EN_OFFSET:  obi_rsp_o.r.rdata = {31'h0, vga_en_q};
          default: begin
            obi_rsp_o.r.rdata = 32'hBADCAB1E;
            obi_rsp_o.r.err   = 1'b1;
          end
        endcase
      end else begin
        unique case ({
          addr_q, 2'b00
        })
          TB_ADDR_OFFSET, CLK_DIV_OFFSET, VGA_EN_OFFSET: ;  // valid write, no error
          default: obi_rsp_o.r.err = 1'b1;
        endcase
      end
    end
  end

endmodule
