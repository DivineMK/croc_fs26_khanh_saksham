// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module ip_vga_fetcher #(
    parameter obi_pkg::obi_cfg_t ObiCfg          = obi_pkg::ObiDefaultConfig,
    parameter int unsigned       RedWidth        = 5,
    parameter int unsigned       GreenWidth      = 6,
    parameter int unsigned       BlueWidth       = 5,
    parameter type               obi_req_t       = logic,
    parameter type               obi_rsp_t       = logic,
    parameter type               ip_vga_reg2hw_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    input ip_vga_reg2hw_t reg2hw_i,
    input logic timing_ready_i,

    // OBI interface to connect with text buffer
    output obi_req_t obi_req_o,
    input  obi_rsp_t obi_rsp_i,

    // Font SRAM write port
    input logic        font_wr_req_i,
    input logic [ 7:0] font_wr_addr_i,
    input logic [63:0] font_wr_data_i,
    input logic [ 7:0] font_wr_be_i,

    output logic [  RedWidth-1:0] red_o,
    output logic [GreenWidth-1:0] green_o,
    output logic [ BlueWidth-1:0] blue_o
);
  import ip_vga_config_pkg::*;

  localparam int unsigned AddrWidth = ObiCfg.AddrWidth;

  // VGA configs
  logic fsm_en;
  logic [$clog2(LineCharWidth)-1:0] vga_line_width;
  logic [$clog2(LineCharHeight)-1:0] vga_line_height;
  logic [$clog2(LineCharWidth*FontWidth)-1:0] vga_h_visible_size;
  logic [$clog2(LineCharHeight*FontHeight)-1:0] vga_v_visible_size;

  // FSMs
  logic [LineCharWidth-1:0][15:0]
      textbuffer_linebuf_d,
      textbuffer_linebuf_q;  // line buffer for fetching char code from text buffer (TB)
  logic [1:0][FontWidth-1:0]
      bitmap_buffer_d, bitmap_buffer_q;  // bitmap buffer for fetching from font
  logic [$clog2(LineCharWidth*FontWidth)-1:0] pixel_horz_q, pixel_horz_d;
  logic [$clog2(LineCharHeight*FontHeight)-1:0]
      pixel_vert_q, pixel_vert_d;  // coordinate in pixel unit
  logic [$clog2(LineCharWidth)-1:0] char_horz;  // coordinate in char unit

  assign char_horz = pixel_horz_q[$clog2(LineCharWidth*FontWidth)-1:$clog2(FontWidth)];

  // font request
  logic [$clog2(LineCharWidth)-1:0]
      font_rd_idx_d,
      font_rd_idx_q;  // index for request from textbuffer_linebuf and write to bitmap_buffer
  logic [FontAddrWidth-1:0] font_rd_addr;
  logic font_rd_req;
  // font response
  logic [FontDataWidth-1:0] font_rd_data;
  logic [FontWidthLog-1:0] font_sel_q, font_sel_d;  // select correct part from font_rd_data

  typedef enum logic [1:0] {
    // FONT_INIT,
    FONT_RSP,
    FONT_REQ
  } font_state_t;
  font_state_t font_state_q, font_state_d;
  // text buffer (TB) request
  logic [$clog2(TBSize)-1:0]
      tb_req_idx_d, tb_req_idx_q;  // index for request from TB and write to textbuffer_linebuf
  obi_req_t obi_tb_req;
  logic [$clog2(LineCharHeight)-1:0]
      tb_vert_q, tb_vert_d;  // coordinate for request from TB, in char unit vertically
  // TB response
  obi_rsp_t obi_tb_rsp;
  logic tb_valid;

  typedef enum logic [1:0] {
    TB_LAST,
    TB_RSP,
    TB_REQ
  } tb_state_t;
  tb_state_t tb_state_q, tb_state_d;

  font #(
      .FontSize(FontSize),
      .FontDataWidth(FontDataWidth)
  ) i_font (
      .clk_i,
      .rst_ni,
      .rd_req_i (font_rd_req),
      .rd_addr_i(font_rd_addr),
      .rd_data_o(font_rd_data),
      .wr_req_i (font_wr_req_i),
      .wr_addr_i(font_wr_addr_i),
      .wr_data_i(font_wr_data_i),
      .wr_be_i  (font_wr_be_i)
  );

  assign fsm_en = reg2hw_i.fsm_en & reg2hw_i.vga_en;
  assign vga_line_width = reg2hw_i.vga_line_width;
  assign vga_line_height = reg2hw_i.vga_line_height;
  assign vga_h_visible_size = reg2hw_i.vga_line_width * FontWidth;
  assign vga_v_visible_size = reg2hw_i.vga_line_height * FontHeight;

  assign obi_req_o = obi_tb_req;
  assign obi_tb_rsp = obi_rsp_i;
  assign tb_valid = obi_tb_rsp.rvalid;  // output from tb valid and ready for new request

  // keep track of current pixel coordinate being displayed
  always_comb begin : pixel_fsm
    pixel_horz_d = pixel_horz_q;
    pixel_vert_d = pixel_vert_q;

    if (fsm_en && timing_ready_i) begin
      pixel_horz_d = pixel_horz_q - 1;
      if (pixel_horz_q == 0) begin  // avoid using _d var to avoid adder in path
        pixel_horz_d = vga_h_visible_size - 1;
        pixel_vert_d = pixel_vert_q - 1;
        if (pixel_vert_q == 0) begin
          pixel_vert_d = vga_v_visible_size - 1;
        end
      end
    end
  end

  // request from text buffer into textbuffer_linebuf
  always_comb begin : tb_fsm
    tb_state_d = tb_state_q;
    textbuffer_linebuf_d = textbuffer_linebuf_q;
    tb_req_idx_d = tb_req_idx_q;
    tb_vert_d = tb_vert_q;
    // NOTE: tb_req_idx need to be down counting because font_rd_idx is down
    // counting, but addr need to be up counting
    obi_tb_req = '0;
    obi_tb_req.a.addr[AddrWidth-1:2] = reg2hw_i.tb_addr[AddrWidth-1:2] + tb_vert_q * (vga_line_width/2) 
                + (vga_line_width/2 - 1 - tb_req_idx_q);
    obi_tb_req.req = '0;

    if (fsm_en) begin
      unique case (tb_state_q)
        TB_RSP: begin
          // receive response and set new request addr
          if (tb_valid) begin
            // tb_rsp contains 2 char code for textbuffer_linebuf
            {textbuffer_linebuf_d[tb_req_idx_q*2], textbuffer_linebuf_d[tb_req_idx_q*2+1]} = obi_tb_rsp.r.rdata;
            obi_tb_req.req = '0;
            // when finished prefetching line
            if (tb_req_idx_q == 0) begin
              tb_state_d = TB_LAST;
            end else begin
              tb_state_d   = TB_REQ;
              tb_req_idx_d = tb_req_idx_q - 1;
            end
          end
        end

        TB_REQ: begin
          // issue request
          obi_tb_req.req = '1;
          if (obi_tb_rsp.gnt) tb_state_d = TB_RSP;
        end

        TB_LAST: begin
          // wait after last request (at the end of line) for line buffer
          // TODO: make condition to start prefetching next line configurable
          if (pixel_horz_q == 'd2 && pixel_vert_q[FontHeightLog-1:0] == 'd0) begin
            tb_state_d = TB_REQ;
            tb_req_idx_d = vga_line_width / 2 - 1;
            tb_vert_d = (tb_vert_q == vga_line_height - 1) ? '0 : tb_vert_q + 1;
          end else begin
            tb_state_d = TB_LAST;
            tb_req_idx_d = tb_req_idx_q;
            tb_vert_d = tb_vert_q;
          end
        end
        // vsim warning
        default: begin
          tb_state_d = TB_REQ;
          obi_tb_req.req = '1;
        end
      endcase
    end
  end

  // request from font into bitmap_buffer
  always_comb begin : font_fsm
    font_rd_addr = textbuffer_linebuf_q[font_rd_idx_q][7:0];
    font_rd_idx_d = font_rd_idx_q;
    font_sel_d = font_sel_q;
    bitmap_buffer_d = bitmap_buffer_q;
    font_state_d = font_state_q;
    font_rd_req = 0;

    unique case (font_state_q)
      FONT_RSP: begin
        // receive response and set new request
        bitmap_buffer_d[font_rd_idx_q[0]] = font_rd_data[font_sel_q*FontWidth+:FontWidth];
        // prefetch 1 cycle BEFORE last pixel of char start
        // 1 cycle for req_idx_q to change, 1 cycle for font to response
        if (pixel_horz_q[FontWidthLog-1:0] == 1 && pixel_horz_d[FontWidthLog-1:0] == 0) begin
          // at end of line
          font_state_d = FONT_REQ;
          if (char_horz == 0) begin
            font_sel_d = pixel_vert_q[FontWidthLog-1:0] - 1;  // move font_sel to next char vertically
            font_rd_idx_d = vga_line_width - 1;
          end else begin
            font_sel_d = pixel_vert_q[FontWidthLog-1:0];
            font_rd_idx_d = char_horz - 1;  // prefetch next char horizontally
          end
        end
      end

      FONT_REQ: begin
        // issue req - 1 cycle rsp
        if (fsm_en) begin
          font_rd_req  = 1;
          font_state_d = FONT_RSP;
        end
      end
      // FONT_INIT: begin
      //   // wait for font to be initialized
      //   if (font_rd_idx_q == vga_line_width - 1) begin
      //     font_state_d = FONT_REQ;
      //     font_rd_idx_d = vga_line_width - 1;
      //     font_sel_d = pixel_vert_q[FontWidthLog-1:0];
      //   end else begin
      //     font_state_d = FONT_INIT;
      //     font_rd_idx_d = font_rd_idx_q + 1;
      //     font_sel_d = pixel_vert_q[FontWidthLog-1:0];
      //   end
      // end
    endcase
  end

  // use bitmap_buffer to get current pixel bitmap
  // TODO: color from config bits
  assign {red_o, green_o, blue_o} = (bitmap_buffer_q[char_horz[0]][pixel_horz_q[FontWidthLog-1:0]] == 1) ? 16'hFFFF : 16'h0;

  always_ff @(posedge clk_i, negedge rst_ni) begin
    // module $_ALDFFE_PNP_ not found
    // cannot use non-constant load on reset
    if (~rst_ni) begin
      pixel_horz_q <= '0;
      pixel_vert_q <= '0;

      font_state_q <= FONT_REQ;
      font_rd_idx_q <= '0;
      font_sel_q <= '0;
      bitmap_buffer_q <= '0;

      tb_req_idx_q <= '0;
      tb_state_q <= TB_REQ;
      tb_vert_q <= '0;
      textbuffer_linebuf_q <= '0;
    end else if (~fsm_en) begin
      pixel_horz_q <= vga_h_visible_size - 1;
      pixel_vert_q <= vga_v_visible_size - 1;

      font_state_q <= FONT_REQ;
      font_rd_idx_q <= vga_line_width - 1;
      font_sel_q <= FontHeight - 1;
      bitmap_buffer_q <= '0;

      tb_req_idx_q <= vga_line_width / 2 - 1;
      tb_state_q <= TB_REQ;
      tb_vert_q <= '0;
      textbuffer_linebuf_q <= '0;
    end else begin
      pixel_horz_q <= pixel_horz_d;
      pixel_vert_q <= pixel_vert_d;

      font_state_q <= font_state_d;
      font_rd_idx_q <= font_rd_idx_d;
      font_sel_q <= font_sel_d;
      bitmap_buffer_q <= bitmap_buffer_d;

      tb_req_idx_q <= tb_req_idx_d;
      tb_state_q <= tb_state_d;
      tb_vert_q <= tb_vert_d;
      textbuffer_linebuf_q <= textbuffer_linebuf_d;
    end
  end
endmodule
