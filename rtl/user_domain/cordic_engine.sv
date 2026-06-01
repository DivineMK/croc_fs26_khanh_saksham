`include "common_cells/registers.svh"
import config_sfr_pkg::*;

module cordic_engine #(
    parameter type config_cordic_t = logic
) (
    input  logic                             clk_i,
    input  logic                             rst_ni,
    input  logic                             start_i,

    input  config_cordic_t                   config_cordic_i,
    input  logic        [     DataWidth-1:0] tan_i,
    input  logic        [PrecisionWidth-1:0] ptr_i,
    output logic signed [     DataWidth-1:0] cordic_x_o,
    output logic signed [     DataWidth-1:0] cordic_y_o
);

  logic [OpModeFieldBitWidth-1:0] opmode;
  logic [CordicInputBitWidth-1:0] cordic_inp;

  assign opmode = config_cordic_i.opmode;
  assign cordic_inp = config_cordic_i.cordic_inp;

  // Internal signal declarations
  logic signed [DataWidth-1:0] X_q, Y_q, Z_q;
  logic signed [DataWidth-1:0] X_d, Y_d, Z_d;
  logic signed [DataWidth-1:0] X_init, Y_init, Z_init;
  logic signed [DataWidth-1:0] X_next, Y_next, Z_next;

  //Implementation only done for Rotation Mode sine/cosine.
  assign X_init = (opmode == 2'h0) ? 'd39797 : 'd0;
  assign Y_init = (opmode == 2'h0) ? 'd0 : 'd0;
  assign Z_init = (opmode == 2'h0) ?
      $signed({{(DataWidth - CordicInputBitWidth) {1'b0}}, cordic_inp}) 
      : $signed('d0);

  always_comb begin : X_Y_Z_nextvalue_calc
    if (Z_q < $signed('d0)) begin
      X_next = X_q + (Y_q >>> ptr_i);
      Y_next = Y_q - (X_q >>> ptr_i);
      Z_next = Z_q + $signed({1'b0, tan_i[DataWidth-2:0]});
    end else begin
      X_next = X_q - (Y_q >>> ptr_i);
      Y_next = Y_q + (X_q >>> ptr_i);
      Z_next = Z_q - $signed({1'b0, tan_i[DataWidth-2:0]});
    end
  end

  assign X_d = (!start_i) ? X_init : X_next;
  assign Y_d = (!start_i) ? Y_init : Y_next;
  assign Z_d = (!start_i) ? Z_init : Z_next;
  `FF(X_q, X_d, X_init, clk_i, rst_ni)
  `FF(Y_q, Y_d, Y_init, clk_i, rst_ni)
  `FF(Z_q, Z_d, Z_init, clk_i, rst_ni)

  assign cordic_x_o = X_q;
  assign cordic_y_o = Y_q;

endmodule
