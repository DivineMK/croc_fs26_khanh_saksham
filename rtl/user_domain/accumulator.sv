module accumulator #(
    parameter WIDTH = 32,
    parameter ADD_OR_SUB = 1 // 1 for addition, 0 for subtraction
) (
    input  logic [WIDTH-1:0] i_data1,
    input  logic [WIDTH-1:0] i_data2,
    output logic [WIDTH:0] data_out
  );

genvar i;


always_comb begin
    data_out = i_data1 + i_data2;
end

endmodule