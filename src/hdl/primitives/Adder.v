module FullAdder(
    input a, b, cin,
    output sum, cout
);
    wire axorbd;
    assign axorbd = a ^ b;
    assign sum = axorbd ^ cin;
    assign cout = (a & b) | (cin & axorbd);
endmodule

module RippleCarryAdder32(
    input [31:0] A, B,
    input Cin,
    output [31:0] Sum,
    output Cout
);
    wire [32:0] carry;
    assign carry[0] = Cin;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : RCAR
            FullAdder fa(
                .a(A[i]), .b(B[i]), .cin(carry[i]), 
                .sum(Sum[i]), .cout(carry[i+1])
            );
        end
    endgenerate
    assign Cout = carry[32];
endmodule
