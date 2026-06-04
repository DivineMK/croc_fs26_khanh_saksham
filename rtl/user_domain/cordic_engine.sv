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
  logic [DataWidth-1:0] cordic_a_inp;

  assign opmode = config_cordic_i.opmode;
  assign cordic_a_inp = config_cordic_i.cordic_a_inp;

  logic signed [DataWidth-1:0] X_d, X_q, X_init, X_next;
  logic signed [DataWidth-1:0] Y_d, Y_q, Y_init, Y_next;
  logic signed [DataWidth-1:0] Z_d, Z_q, Z_init, Z_next;

  // Quadrant of the input angle (2π = 2^32)
  logic [1:0] quadrant;
  assign quadrant = cordic_a_inp[31:30];

  // 39797 = 1/K in Q15.16 format, K is the CORDIC gain correction factor
  always_comb begin : init_values
    unique case (opmode)
      2'h0: begin
        // Sincos mode: rotate unit vector by angle (gain pre-compensated)
        Z_init = $signed({2'b0, cordic_a_inp[DataWidth-3:0]});
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
        // Vector mode: rotate (X, Y) by angle θ = quadrant×90° + Z_remainder
        // Pre-rotate (X,Y) by quadrant×90° so CORDIC only rotates Z in [0, π/2)
        // Output includes K_gain factor; SW post-multiplies by 1/K_gain
        unique case (quadrant)
          2'b00: begin
            X_init = config_cordic_i.cordic_x_inp;
            Y_init = config_cordic_i.cordic_y_inp;
          end
          2'b01: begin
            X_init = -config_cordic_i.cordic_y_inp;
            Y_init =  config_cordic_i.cordic_x_inp;
          end
          2'b10: begin
            X_init = -config_cordic_i.cordic_x_inp;
            Y_init = -config_cordic_i.cordic_y_inp;
          end
          2'b11: begin
            X_init =  config_cordic_i.cordic_y_inp;
            Y_init = -config_cordic_i.cordic_x_inp;
          end
        endcase
        Z_init = $signed({2'b0, cordic_a_inp[DataWidth-3:0]});
      end
      default: begin
        X_init = 'd0;
        Y_init = 'd0;
        Z_init = 'd0;
      end
    endcase
  end

  always_comb begin : X_Y_Z_nextvalue_calc
    // if (Z_q < $signed('d0)) begin
    if (Z_q[DataWidth-1]) begin
      X_next = X_q + (Y_q >>> iteration_q);
      Y_next = Y_q - (X_q >>> iteration_q);
      Z_next = Z_q + $signed({1'b0, atan_i[DataWidth-2:0]});
    end else begin
      X_next = X_q - (Y_q >>> iteration_q);
      Y_next = Y_q + (X_q >>> iteration_q);
      Z_next = Z_q - $signed({1'b0, atan_i[DataWidth-2:0]});
    end
  end

  // FSM + datapath control
  `FF(state_q, state_d, IDLE, clk_i, rst_ni)
  `FF(iteration_q, iteration_d, 'd0, clk_i, rst_ni)
  `FF(X_q, X_d, X_init, clk_i, rst_ni)
  `FF(Y_q, Y_d, Y_init, clk_i, rst_ni)
  `FF(Z_q, Z_d, Z_init, clk_i, rst_ni)

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

endmodule
