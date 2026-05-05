// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module ip_vga_fetcher #(
    parameter obi_pkg::obi_cfg_t ObiCfg     = obi_pkg::ObiDefaultConfig,
    parameter int unsigned       RedWidth   = 5,
    parameter int unsigned       GreenWidth = 6,
    parameter int unsigned       BlueWidth  = 5,
    parameter type               obi_req_t  = logic,
    parameter type               obi_rsp_t  = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input logic vga_en_i,
    input logic [ObiCfg.AddrWidth-1:0] tb_addr_i,
    input logic timing_ready_i,

    // OBI Data ports
    output obi_req_t obi_req_o,
    input  obi_rsp_t obi_rsp_i,

    output logic [  RedWidth-1:0] red_o,
    output logic [GreenWidth-1:0] green_o,
    output logic [ BlueWidth-1:0] blue_o
);
  import ip_vga_config_pkg::*;

  localparam int unsigned AddrWidth = ObiCfg.AddrWidth;

  logic [LineCharWidth-1:0][15:0]
      textbuffer_linebuf_d,
      textbuffer_linebuf_q;  // line buffer for fetching char code from text buffer (TB)
  logic [1:0][FontWidth-1:0]
      bitmap_buffer_d, bitmap_buffer_q;  // bitmap buffer for fetching from font
  logic [31:0] pixel_horz_q, pixel_horz_d, pixel_vert_q, pixel_vert_d;  // coordinate in pixel unit
  logic [28:0] char_horz;  // coordinate in char unit

  assign char_horz = pixel_horz_q >> $clog2(FontWidth);

  // font request
  logic [$clog2(LineCharWidth)-1:0]
      font_req_idx_d,
      font_req_idx_q;  // index for request from textbuffer_linebuf and write to bitmap_buffer
  logic [FontAddrWidth-1:0] font_req;
  // font response
  logic [FontDataWidth-1:0] font_rsp;
  logic [FontWidthLog-1:0] font_sel_q, font_sel_d;  // select correct part from font_rsp

  // text buffer (TB) request
  logic [$clog2(TBSize)-1:0]
      tb_req_idx_d, tb_req_idx_q;  // index for request from TB and write to textbuffer_linebuf
  obi_req_t obi_tb_req;
  logic [31:0] tb_vert_q, tb_vert_d;  // coordinate for request from TB, in char unit vertically
  // TB response
  obi_rsp_t obi_tb_rsp;
  logic tb_valid;

  typedef enum logic {
    FONT_REQ,
    FONT_IDLE
  } font_state_t;

  font_state_t font_state_q, font_state_d;

  typedef enum logic [1:0] {
    TB_LAST,
    TB_REQ,
    TB_IDLE
  } tb_state_t;
  tb_state_t tb_state_q, tb_state_d;

  font_rom #(
      .FontSize(FontSize),
      .FontWidth(FontWidth),
      .FontHeight(FontHeight),
      .FontDataWidth(FontDataWidth)
  ) i_font (
      .clk_i,
      .rst_ni,
      .req_addr_i(font_req),
      .rsp_data_o(font_rsp)
  );

  assign obi_req_o = obi_tb_req;
  assign obi_tb_rsp = obi_rsp_i;

  assign tb_valid = obi_tb_rsp.rvalid;  // output from tb valid and ready for new request

  assign obi_tb_req.a.we = '0;  // read only
  assign obi_tb_req.a.aid = '0;  // TB id

  always_comb begin : pixel_fsm
    pixel_horz_d = pixel_horz_q;
    pixel_vert_d = pixel_vert_q;

    if (vga_en_i && timing_ready_i) begin
      pixel_horz_d = pixel_horz_q - 1;
      if (pixel_horz_q == 0) begin  // avoid using _d var to avoid adder in path
        pixel_horz_d = HoriVisibleSize - 1;
        pixel_vert_d = pixel_vert_q - 1;
        if (pixel_vert_q == 0) begin
          pixel_vert_d = VertVisibleSize - 1;
        end
      end
    end
  end

  always_comb begin : tb_fsm
    tb_state_d = tb_state_q;
    textbuffer_linebuf_d = textbuffer_linebuf_q;
    tb_req_idx_d = tb_req_idx_q;
    tb_vert_d = tb_vert_q;
    obi_tb_req.a.addr[AddrWidth-1:2] = tb_addr_i[AddrWidth-1:2] + tb_vert_q * (LineCharWidth/2) 
                + (LineCharWidth/2 - 1 - tb_req_idx_q); // tb_req_idx is down counting, tb_req is up counting
    obi_tb_req.req = '0;  // default to prefetch

    unique case (tb_state_q)
      TB_REQ: begin
        // receive response and set new request addr
        if (tb_valid) begin
          textbuffer_linebuf_d[tb_req_idx_q*2+:2] = obi_tb_rsp.r.rdata;
          obi_tb_req.req = '0;
          // when finished prefetching line
          if (tb_req_idx_q == 0) begin
            tb_state_d = TB_LAST;
          end else begin
            // tb_rsp contains 2 char code
            tb_state_d   = TB_IDLE;
            tb_req_idx_d = tb_req_idx_q - 1;
          end
        end
      end

      TB_IDLE: begin
        // issue request
        obi_tb_req.req = '1;
        tb_state_d = TB_REQ;
      end

      TB_LAST: begin
        // wait after filling last request for line buffer
        // TODO: make condition to start prefetching next line configurable
        if (pixel_horz_q == 'd2 && pixel_vert_q[FontHeightLog-1:0] == 'd0) begin
          tb_state_d = TB_IDLE;
          tb_req_idx_d = LineCharWidth / 2 - 1;
          tb_vert_d = (tb_vert_q == LineCharHeight - 1) ? '0 : tb_vert_q + 1;
        end else begin
          tb_state_d = TB_LAST;
          tb_req_idx_d = tb_req_idx_q;
          tb_vert_d = tb_vert_q;
        end
      end
      // vsim warning
      default: begin
        tb_state_d = TB_REQ;
        obi_tb_req.req = '0;
        tb_req_idx_d = LineCharWidth / 2 - 1;
      end
    endcase
  end

  // request from font into bitmap_buffer
  always_comb begin : font_fsm
    font_req = textbuffer_linebuf_q[font_req_idx_q][7:0];
    font_req_idx_d = font_req_idx_q;
    font_state_d = font_state_q;
    font_sel_d = font_sel_q;
    bitmap_buffer_d = bitmap_buffer_q;

    unique case (font_state_q)
      FONT_REQ: begin
        // receive response and set new request
        bitmap_buffer_d[font_req_idx_q[0]] = font_rsp[font_sel_q*FontWidth+:FontWidth];
        // switch to FONT_REQ to prefetch 1 cycle before last pixel of char start
        // 1 cycle for req_idx_q to change, 1 cycle for font to response
        // depend on clk_div
        if (pixel_horz_q[2:0] == 1 && pixel_horz_d[2:0] == 0) begin
          // at end of line
          if (char_horz == 0) begin
            font_sel_d = pixel_vert_q[2:0] - 1;  // move font_sel to next char vertically
            font_req_idx_d = LineCharWidth - 1;
          end else begin
            font_sel_d = pixel_vert_q[2:0];
            font_req_idx_d = char_horz - 1;  // prefetch next char horizontally
          end
        end
      end

      FONT_IDLE: begin
        font_state_d = FONT_REQ;
      end

      default: begin
        font_req_idx_d = LineCharWidth - 1;
        font_state_d   = FONT_IDLE;
      end
    endcase
  end

  // use bitmap_buffer to get current pixel bitmap
  // TODO: color from config bits
  assign {red_o, green_o, blue_o} = (bitmap_buffer_q[char_horz[0]][pixel_horz_q[2:0]] == 1) ? 16'hFFFF : 16'h0;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    if (~rst_ni || ~vga_en_i) begin
      pixel_horz_q <= HoriVisibleSize - 1;
      pixel_vert_q <= VertVisibleSize - 1;

      font_req_idx_q <= LineCharWidth - 1;
      font_state_q <= FONT_IDLE;
      font_sel_q <= FontHeight - 1;
      bitmap_buffer_q <= '0;

      tb_req_idx_q <= LineCharWidth / 2 - 1;
      tb_state_q <= TB_IDLE;
      tb_vert_q <= '0;
      textbuffer_linebuf_q <= '0;
    end else begin
      pixel_horz_q <= pixel_horz_d;
      pixel_vert_q <= pixel_vert_d;

      font_req_idx_q <= font_req_idx_d;
      font_state_q <= font_state_d;
      font_sel_q <= font_sel_d;
      bitmap_buffer_q <= bitmap_buffer_d;

      tb_req_idx_q <= tb_req_idx_d;
      tb_state_q <= tb_state_d;
      tb_vert_q <= tb_vert_d;
      textbuffer_linebuf_q <= textbuffer_linebuf_d;
    end
  end
endmodule
