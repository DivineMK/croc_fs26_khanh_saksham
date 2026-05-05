import ip_vga_config_pkg::*;

module font_rom #(
    parameter int unsigned FontSize = FontSize,
    parameter int unsigned FontAddrWidth = $clog2(FontSize),
    parameter int unsigned FontWidth = FontWidth,
    parameter int unsigned FontHeight = FontHeight,
    parameter int unsigned FontDataWidth = FontDataWidth
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic [FontAddrWidth-1:0] req_addr_i,
    output logic [FontDataWidth-1:0] rsp_data_o
);

  logic [FontSize-1:0][FontDataWidth-1:0] font;
  logic [FontAddrWidth-1:0] req_d, req_q;

  always_comb begin : font_init
    for (int unsigned i = 0; i < FontSize; i += 4) begin
      font[i] = {
        8'b00000000,
        8'b00010000,
        8'b00111000,
        8'b01101100,
        8'b01101100,
        8'b11111110,
        8'b11000110,
        8'b00000000
      };

      font[i+1] = {
        8'b00000000,
        8'b11111100,
        8'b01100110,
        8'b01111100,
        8'b01100110,
        8'b01100110,
        8'b11111100,
        8'b00000000
      };

      font[i+2] = {
        8'b00000000,
        8'b01111100,
        8'b11000110,
        8'b11000000,
        8'b11000000,
        8'b11000110,
        8'b01111100,
        8'b00000000
      };

      font[i+3] = {
        8'b00000000,
        8'b11111100,
        8'b01100110,
        8'b01100110,
        8'b01100110,
        8'b01100110,
        8'b11111100,
        8'b00000000
      };
    end
  end

  assign req_d = req_addr_i;
  assign rsp_data_o = font[req_q];

  always_ff @(posedge clk_i, negedge rst_ni) begin : ff
    if (~rst_ni) begin
      req_q <= '0;
    end else begin
      req_q <= req_d;
    end
  end
  // https://github.com/alexfru/512_8/blob/master/512_8_bold.txt
  //    00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
  //    11111110 11111110 01111100 11000110 11111100 00011110 11100110 11110000 11000110 11000110 01111100
  //    01100010 01100010 11000110 11000110 00110000 00001100 01101100 01100000 11101110 11100110 11000110
  //    01111000 01111000 11000000 11111110 00110000 00001100 01111000 01100000 11111110 11010110 11000110
  //    01100000 01100000 11001110 11000110 00110000 00001100 01101100 01100000 11010110 11010110 11000110
  //    01100010 01100000 11000110 11000110 00110000 11001100 01100110 01100100 11000110 11001110 11000110
  //    11111110 11110000 01111100 11000110 11111100 01111000 11100110 11111100 11000110 11000110 01111100
  //    00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
endmodule
