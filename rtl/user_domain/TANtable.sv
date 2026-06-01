import config_sfr_pkg::PrecisionWidth;
import config_sfr_pkg::DataWidth;

module TANtable #(
) (
    input logic [PrecisionWidth-1:0] ptr_i,
    output logic [DataWidth-1:0] atan_o
);
  logic [31:0] atan;
  assign atan_o = atan[31:32-DataWidth];

  always_comb begin
    unique case (ptr_i)
       0: atan = 32'd536870912;  // Q0.32 format atan(2^-0) = π/4  →  2^32 / 8
       1: atan = 32'd316933406;  // Q0.32 format atan(2^-1)
       2: atan = 32'd167466358;  // Q0.32 format atan(2^-2)
       3: atan = 32'd85012769;   // Q0.32 format atan(2^-3)
       4: atan = 32'd42673528;   // Q0.32 format atan(2^-4)
       5: atan = 32'd21354918;   // Q0.32 format atan(2^-5)
       6: atan = 32'd10680707;   // Q0.32 format atan(2^-6)
       7: atan = 32'd5340354;    // Q0.32 format atan(2^-7)
       8: atan = 32'd2670177;    // Q0.32 format atan(2^-8)
       9: atan = 32'd1335088;    // Q0.32 format atan(2^-9)
      10: atan = 32'd667544;     // Q0.32 format atan(2^-10)
      11: atan = 32'd333772;     // Q0.32 format atan(2^-11)
      12: atan = 32'd166886;     // Q0.32 format atan(2^-12)
      13: atan = 32'd83443;      // Q0.32 format atan(2^-13)
      14: atan = 32'd41722;      // Q0.32 format atan(2^-14)
      15: atan = 32'd20861;      // Q0.32 format atan(2^-15)
      default: atan = 'x;
    endcase
  end
endmodule
