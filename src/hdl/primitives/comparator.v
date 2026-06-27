`timescale 1ns / 1ps

module one_bit_comparator(
    input  a,
    input  b,
    input  less_prev,
    input  greater_prev,
    input  equal_prev,
    output less,
    output greater,
    output equal
    );

    wire a_lt_b, a_gt_b, a_eq_b;

    assign a_lt_b = (~a) & b;
    assign a_gt_b = a & (~b);
    assign a_eq_b = ~(a ^ b);

    // Final outputs – priority: previous result > current bit difference
    assign less   = less_prev | (equal_prev & a_lt_b);
    assign greater = greater_prev | (equal_prev & a_gt_b);
    assign equal  = equal_prev & a_eq_b;

endmodule
