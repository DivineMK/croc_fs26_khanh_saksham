// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Enrico Zelioli <ezelioli@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

import config_sfr_pkg::*;
module config_sfr #(
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic,
    parameter type config_cordic_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input  obi_req_t obi_req_i,
    output obi_rsp_t obi_rsp_o,

    input  logic signed    [SfrDataWidth-1:0] cordic_oup_x_i,
    input  logic signed    [SfrDataWidth-1:0] cordic_oup_y_i,
    input  logic                              cordic_done_i,
    output config_cordic_t                    config_cordic_o,
    output logic                              cordic_start_o,
    output logic                              irq_o
);

  // Read-write registers
  logic [PrecisionWidth-1:0] precision_d, precision_q;
  logic [SfrDataWidth-1:0] misc_d, misc_q;
  logic [OpTypeFieldBitWidth-1:0] optype_d, optype_q;
  logic [OpModeFieldBitWidth-1:0] opmode_d, opmode_q;
  logic [CordicInputBitWidth-1:0] cordic_inp_d, cordic_inp_q;
  logic signed [SfrDataWidth-1:0] cordic_oup_x_q, cordic_oup_x_d;
  logic signed [SfrDataWidth-1:0] cordic_oup_y_q, cordic_oup_y_d;
  logic status_q, status_d;
  logic irq_d, irq_q;

  `FF(precision_q, precision_d, 4'd15, clk_i, rst_ni)
  `FF(misc_q, misc_d, '0, clk_i, rst_ni)
  `FF(optype_q, optype_d, '0, clk_i, rst_ni)
  `FF(opmode_q, opmode_d, '0, clk_i, rst_ni)
  `FF(cordic_inp_q, cordic_inp_d, '0, clk_i, rst_ni)
  `FF(cordic_oup_x_q, cordic_oup_x_d, '0, clk_i, rst_ni)
  `FF(cordic_oup_y_q, cordic_oup_y_d, '0, clk_i, rst_ni)

  // OBI A-phase fields latched for the R-phase
  logic                              req_q;
  logic                              we_q;
  logic [$bits(obi_req_i.a.aid)-1:0] id_q;
  logic [          IntAddrWidth-1:2] addr_q;

  `FF(req_q, obi_req_i.req, '0, clk_i, rst_ni)
  `FF(we_q, obi_req_i.a.we, '0, clk_i, rst_ni)
  `FF(id_q, obi_req_i.a.aid, '0, clk_i, rst_ni)
  `FF(addr_q, obi_req_i.a.addr[IntAddrWidth-1:2], '0, clk_i, rst_ni)
  // replace start logic from control unit -> remove PRESTART
  `FF(status_q, status_d, '0, clk_i, rst_ni)
  `FF(irq_q, irq_d, '0, clk_i, rst_ni)

  // Byte-enable mask: expands each BE bit to a full byte for masked writes
  logic [SfrDataWidth-1:0] be_mask;
  for (genvar i = 0; unsigned'(i) < SfrDataWidth / 8; ++i) begin : gen_write_mask
    assign be_mask[8*i+:8] = {8{obi_req_i.a.be[i]}};
  end

  // TODO: whether full addr need to be checked or just LSBs
  // Access-valid flags (combinational from request-phase address)
  // assign sfraccess_valid_o    = (obi_req_i.a.addr[IntAddrWidth-1:2] == PRECISION_SFR_OFFSET)
  //                            || (obi_req_i.a.addr[IntAddrWidth-1:2] == MISC_SFR_OFFSET)
  //                            || (obi_req_i.a.addr[IntAddrWidth-1:2] == OPERATION_SFR_OFFSET);
  // assign opsfr_access_valid_o = (obi_req_i.a.addr[IntAddrWidth-1:2] == OPERATION_SFR_OFFSET);

  // Output to hardware
  assign config_cordic_o.precision = precision_q;
  assign config_cordic_o.optype = optype_q;
  assign config_cordic_o.opmode = opmode_q;
  assign config_cordic_o.cordic_inp = cordic_inp_d;  // save 1 cycle over using _q
  assign config_cordic_o.drcg_en = misc_q[0];
  assign cordic_start_o = (status_q == 1);
  assign irq_o = irq_q;

  always_comb begin : irq
    irq_d = irq_q;
    if (cordic_done_i) begin
      irq_d = 1'b1;
    end

    if (obi_req_i.req && !obi_req_i.a.we)
      unique case ({
        obi_req_i.a.addr[IntAddrWidth-1:2], 2'b00
      })
        OUTPUT_X_OFFSET, OUTPUT_Y_OFFSET, STATUS_OFFSET: irq_d = 1'b0;
        default: ;
      endcase
  end
  // Address phase: update writable registers
  always_comb begin : write_fsm
    precision_d    = precision_q;
    misc_d         = misc_q;
    optype_d       = optype_q;
    opmode_d       = opmode_q;
    cordic_inp_d   = cordic_inp_q;
    status_d       = status_q;
    cordic_oup_x_d = cordic_oup_x_q;
    cordic_oup_y_d = cordic_oup_y_q;

    // clear status bit when done
    if (cordic_done_i) begin
      status_d = 1'b0;
      cordic_oup_x_d = cordic_oup_x_i;
      cordic_oup_y_d = cordic_oup_y_i;
    end
    // TODO: determine whether to have cordic_engine store current config
    // TODO: whether full addr need to be checked or just LSBs
    if (obi_req_i.req && obi_req_i.a.we && !status_q) begin
      unique case ({
        obi_req_i.a.addr[IntAddrWidth-1:2], 2'b00
      })
        PRECISION_SFR_OFFSET: begin
          precision_d = obi_req_i.a.wdata[PrecisionWidth-1:0] & be_mask[PrecisionWidth-1:0];
        end

        MISC_SFR_OFFSET: begin
          misc_d = obi_req_i.a.wdata & be_mask;
        end

        OPTYPE_SFR_OFFSET: begin
          optype_d = obi_req_i.a.wdata[OpTypeFieldBitWidth-1:0] & be_mask[OpTypeFieldBitWidth-1:0];
        end

        OPMODE_SFR_OFFSET: begin
          opmode_d = obi_req_i.a.wdata[OpModeFieldBitWidth-1:0] & be_mask[OpModeFieldBitWidth-1:0];
        end

        INPUT_OFFSET: begin
          cordic_inp_d = obi_req_i.a.wdata[CordicInputBitWidth-1:0] & be_mask[CordicInputBitWidth-1:0];
          status_d = 1'b1;  // Start CORDIC computation when input is written
        end

        default: ;
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
          PRECISION_SFR_OFFSET: begin
            obi_rsp_o.r.rdata = {{(SfrDataWidth - PrecisionWidth) {1'b0}}, precision_q};
          end

          MISC_SFR_OFFSET: begin
            obi_rsp_o.r.rdata = misc_q;
          end

          OPTYPE_SFR_OFFSET: begin
            obi_rsp_o.r.rdata = {{(SfrDataWidth - OpTypeFieldBitWidth) {1'b0}}, optype_q};
          end

          OPMODE_SFR_OFFSET: begin
            obi_rsp_o.r.rdata = {{(SfrDataWidth - OpModeFieldBitWidth) {1'b0}}, opmode_q};
          end

          INPUT_OFFSET: begin
            obi_rsp_o.r.rdata = {{(SfrDataWidth - CordicInputBitWidth) {1'b0}}, cordic_inp_q};
          end

          OUTPUT_X_OFFSET: begin
            obi_rsp_o.r.rdata = cordic_oup_x_q;
          end

          OUTPUT_Y_OFFSET: begin
            obi_rsp_o.r.rdata = cordic_oup_y_q;
          end

          STATUS_OFFSET: begin
            obi_rsp_o.r.rdata = {{(SfrDataWidth - 1) {1'b0}}, status_q};
          end

          default: begin
            obi_rsp_o.r.rdata = 32'hBADCAB1E;
            obi_rsp_o.r.err   = 1'b1;
          end
        endcase
      end else begin
        unique case ({
          addr_q, 2'b00
        })
          PRECISION_SFR_OFFSET, MISC_SFR_OFFSET, OPTYPE_SFR_OFFSET, OPMODE_SFR_OFFSET, INPUT_OFFSET:
          ;
          // STATUS_OFFSET and OUTPUT_OFFSET are read-only

          default: obi_rsp_o.r.err = 1'b1;
        endcase
      end
    end
  end

endmodule
