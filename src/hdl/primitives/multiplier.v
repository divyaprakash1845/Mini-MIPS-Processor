module multiplier(
    input clk,
    input reset,
    input signed [31:0] multiplicand,
    input signed [31:0] multiplier,
    output reg [31:0] product_high,
    output reg [31:0] product_low,
    output reg done
);

reg signed [63:0] product;
reg signed [31:0] count;
reg signed [31:0] multiplier_abs;
reg sign;

always @(posedge clk)
begin

    if(reset)
    begin
        product <= 0;
        count <= 0;
        done <= 0;

        sign <= multiplier[31];
        multiplier_abs <= multiplier[31] ? -multiplier : multiplier;
    end

    else if(done == 0)
    begin

        if(count < multiplier_abs)
        begin
            product <= product + multiplicand;
            count <= count + 1;
        end

        else
        begin
            if(sign)
                product <= -product;

            product_high <= product[63:32];
            product_low <= product[31:0];
            done <= 1;
        end

    end

end

endmodule
