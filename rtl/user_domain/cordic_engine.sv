`include "common_cells/registers.svh"
import config_sfr_pkg::*;

module cordic_engine #(
    parameter type config_cordic_t = logic
) (
    input  logic                                clk_i,
    input  logic                                rst_ni,
    input  logic                                start_i,
    input  config_cordic_t                      config_cordic_i,
    input  logic           [     DataWidth-1:0] atan_i,
    output logic           [PrecisionWidth-1:0] ptr_o,
    output logic signed    [     DataWidth-1:0] cordic_x_o,
    output logic signed    [     DataWidth-1:0] cordic_y_o,
    output logic signed    [     DataWidth-1:0] cordic_z_o,
    output logic                                done_o
);

  // FSM state
  typedef enum logic [1:0] {
    IDLE,
    RUN,
    DONE
  } state_t;

  state_t state_q, state_d;
  logic [PrecisionWidth-1:0] iteration_q, iteration_d;

  // CORDIC datapath
  logic [OpModeFieldBitWidth-1:0] opmode;
  logic [DataWidth-1:0] cordic_inp_z;
  logic signed [DataWidth-1:0] cordic_inp_x;
  logic signed [DataWidth-1:0] cordic_inp_y;

  assign opmode = config_cordic_i.opmode;
  assign cordic_inp_z = config_cordic_i.cordic_inp_z;
  assign cordic_inp_x = config_cordic_i.cordic_inp_x;
  assign cordic_inp_y = config_cordic_i.cordic_inp_y;

  logic signed [DataWidth-1:0] X_d, X_q, X_init, X_next;
  logic signed [DataWidth-1:0] Y_d, Y_q, Y_init, Y_next;
  logic signed [DataWidth-1:0] Z_d, Z_q, Z_init, Z_next;

  // Vectoring mode: rotation direction based on Y sign (drive Y to 0)
  // Rotation/sincos modes: direction based on Z sign (consume angle)
  logic rot_dir;
  assign rot_dir = (opmode == 2'h2) ? ~Y_q[DataWidth-1] : Z_q[DataWidth-1];

  // Quadrant of the input angle (2pi = 2^32)
  logic [1:0] quadrant;
  assign quadrant = cordic_inp_z[31:30];

  // 39797 = 1/K in Q15.16 format, K is the CORDIC gain correction factor
  always_comb begin : init_values
    unique case (opmode)
      2'h0: begin
        // Sincos mode: rotate unit vector by angle (gain pre-compensated)
        // Pre-rotate so that Z stays in [0, pi/2)
        Z_init = $signed({2'b0, cordic_inp_z[DataWidth-3:0]});
        unique case (quadrant)
          2'b00: begin
            X_init = 'd39797;
            Y_init = 'd0;
          end
          2'b01: begin
            X_init = 'd0;
            Y_init = 'd39797;
          end
          2'b10: begin
            X_init = -'d39797;
            Y_init = 'd0;
          end
          2'b11: begin
            X_init = 'd0;
            Y_init = -'d39797;
          end
        endcase
      end
      2'h1: begin
        // Vector mode: rotate (X, Y) by an angle
        // Pre-rotate so that Z stays in [0, pi/2)
        // X, Y output includes K_gain factor; SW post-multiplies by 1/K_gain
        unique case (quadrant)
          2'b00: begin
            X_init = cordic_inp_x;
            Y_init = cordic_inp_y;
          end
          2'b01: begin
            X_init = -cordic_inp_y;
            Y_init = cordic_inp_x;
          end
          2'b10: begin
            X_init = -cordic_inp_x;
            Y_init = -cordic_inp_y;
          end
          2'b11: begin
            X_init = cordic_inp_y;
            Y_init = -cordic_inp_x;
          end
        endcase
        Z_init = $signed({2'b0, cordic_inp_z[DataWidth-3:0]});
      end
      2'h2: begin
        // Vectoring mode: find angle and magnitude of (X, Y)
        // Z accumulates the angle; Y converges to 0
        // X output includes K_gain factor; SW post-multiplies by 1/K_gain
        // Full circle: when X < 0, pre-rotate by 180deg and seed Z = pi
        if (cordic_inp_x[DataWidth-1]) begin
          X_init = -cordic_inp_x;
          Y_init = -cordic_inp_y;
          Z_init = $signed(32'h80000000);  // pi in normalized angle (pi = 2^31)
        end else begin
          X_init = cordic_inp_x;
          Y_init = cordic_inp_y;
          Z_init = '0;
        end
      end
      default: begin
        X_init = 'd0;
        Y_init = 'd0;
        Z_init = 'd0;
      end
    endcase
  end

  // Reference: https://zipcpu.com/dsp/2017/08/30/cordic.html
  // CORDIC rotation step -- single iteration i.
  //
  // The CORDIC approximates a rotation matrix using only shifts and adds.
  // K_gain = prod(sqrt(1+2^-2i)) ~ 1.6468 (constant wrt precision, can be compensated in SW)
  // Each iteration applies one of two pseudo-rotation matrices:
  //
  // rot_dir = 1 (Z accumulates +atan):       rot_dir = 0 (Z accumulates -atan):
  //
  // |x_next|   | 1    2^-i | |x|            |x_next|   | 1   -2^-i | |x|
  // |y_next| = |-2^-i   1  | |y|            |y_next| = | 2^-i   1  | |y|
  //
  // z_next = z + atan(2^-i)                 z_next = z - atan(2^-i)
  //
  // Direction selection per mode:
  //   Rotation/sincos (opmode 0/1): rot_dir = Z sign
  //     Z > 0 (positive angle remaining) -> rot_dir=0, CCW rotation, Z -= atan
  //     Z < 0 (negative angle)           -> rot_dir=1, CW  rotation, Z += atan
  // After N iterations: |Y| -> 0, X ~ magnitude * K_gain, Z ~ angle
  //
  //   Vectoring (opmode 2): rot_dir = ~Y sign
  //     Y > 0 (above X-axis) -> rot_dir=1, CW rotation, Y decreases toward 0
  //     Y < 0 (below X-axis) -> rot_dir=0, CCW rotation, Y increases toward 0
  // After N iterations: |Y| -> 0, X ~ magnitude * K_gain, Z ~ angle
  always_comb begin : X_Y_Z_nextvalue_calc
    if (rot_dir) begin
      // CW
      X_next = X_q + (Y_q >>> iteration_q);
      Y_next = Y_q - (X_q >>> iteration_q);
      Z_next = Z_q + $signed({1'b0, atan_i[DataWidth-2:0]});
    end else begin
      // CCW
      X_next = X_q - (Y_q >>> iteration_q);
      Y_next = Y_q + (X_q >>> iteration_q);
      Z_next = Z_q - $signed({1'b0, atan_i[DataWidth-2:0]});
    end
  end

  // FSM + datapath control
  `FF(state_q, state_d, IDLE, clk_i, rst_ni)
  `FF(iteration_q, iteration_d, '0, clk_i, rst_ni)
  `FF(X_q, X_d, '0, clk_i, rst_ni)
  `FF(Y_q, Y_d, '0, clk_i, rst_ni)
  `FF(Z_q, Z_d, '0, clk_i, rst_ni)

  always_comb begin
    state_d    = state_q;
    iteration_d = iteration_q;
    X_d = X_q;
    Y_d = Y_q;
    Z_d = Z_q;

    unique case (state_q)
      IDLE: begin
        X_d = X_init;
        Y_d = Y_init;
        Z_d = Z_init;
        if (start_i) begin
          state_d = RUN;
        end
      end

      RUN: begin
        X_d = X_next;
        Y_d = Y_next;
        Z_d = Z_next;
        iteration_d = iteration_q + 1;
        if (iteration_q == config_cordic_i.precision) begin
          state_d = DONE;
          iteration_d = iteration_q;
        end
      end

      DONE: begin
        state_d = IDLE;
        iteration_d = '0;
      end

      default: begin
        state_d = IDLE;
        iteration_d = '0;
      end
    endcase
  end

  assign ptr_o = iteration_q;
  assign done_o = (state_q == DONE);
  assign cordic_x_o = X_q;
  assign cordic_y_o = Y_q;
  assign cordic_z_o = Z_q;

endmodule
