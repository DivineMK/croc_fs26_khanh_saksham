module TANtable #(
    parameter MaxIterationDepth = 16,
    parameter DataWidth = 32,

    //Derived parameter
    parameter PtrWidth = $clog2(MaxIterationDepth)
) (
    input  logic [PtrWidth-1:0] ptr_i,
    output logic [DataWidth-1:0] tan_o
);


always_comb begin
    unique case ( ptr_i )
        0:  tan_o = 32'd51472;    // atan(2^-0) in Q1.31 format
        1:  tan_o = 32'd30386;    // atan(2^-1) in Q1.31 format
        2:  tan_o = 32'd16055;    // atan(2^-2) in Q1.31 format
        3:  tan_o = 32'd8150;     // atan(2^-3) in Q1.31 format
        4:  tan_o = 32'd4091;     // atan(2^-4) in Q1.31 format
        5:  tan_o = 32'd2047;     // atan(2^-5) in Q1.31 format
        6:  tan_o = 32'd1024;     // atan(2^-6) in Q1.31 format
        7:  tan_o = 32'd512;      // atan(2^-7) in Q1.31 format
        8:  tan_o = 32'd256;      // atan(2^-8) in Q1.31 format
        9:  tan_o = 32'd128;      // atan(2^-9) in Q1.31 format
        10: tan_o = 32'd64;       // atan(2^-10) in Q1.31 format
        11: tan_o = 32'd32;       // atan(2^-11) in Q1.31 format
        12: tan_o = 32'd16;       // atan(2^-12) in Q1.31 format
        13: tan_o = 32'd8;        // atan(2^-13) in Q1.31 format
        14: tan_o = 32'd4;        // atan(2^-14) in Q1.31 format
        15: tan_o = 32'd2;        // atan(2^-15) in Q1.31 format
        default: tan_o = 32'dx;   // Undefined for ptr_i >= MaxIterationDepth 
    endcase
end


endmodule