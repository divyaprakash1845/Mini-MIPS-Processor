module divider(
    input clk,
    input reset,
    input [31:0] dividend,
    input [31:0] divisor,
    output reg [31:0] quotient,
    output reg [31:0] remainder,
    output reg done
);

reg [31:0] current_dividend;
reg [31:0] count;

always @(posedge clk)
begin

    if(reset)
    begin
        current_dividend <= dividend;
        count <= 0;
        quotient <= 0;
        remainder <= 0;
        done <= 0;
    end

    else if(done == 0)
    begin

        if(divisor == 0)
        begin
            quotient <= 32'hFFFFFFFF;
            remainder <= 0;
            done <= 1;
        end

        else if(divisor == 1)
        begin
            quotient <= dividend;
            remainder <= 0;
            done <= 1;
        end

        else if(current_dividend >= divisor)
        begin
            current_dividend <= current_dividend - divisor;
            count <= count + 1;
        end

        else
        begin
            quotient <= count;
            remainder <= current_dividend;
            done <= 1;
        end

    end

end

endmodule
