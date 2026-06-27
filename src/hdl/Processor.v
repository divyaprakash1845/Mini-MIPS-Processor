`timescale 1ns / 1ps
`include "defs.vh"

module Processor(
    input clk, 
    output halt, 
    input reset, 
    output reg [7:0] pc, 
    input [31:0] ins, 
    output [31:0] io_reg1, 
    output [31:0] io_reg2, 
    output [31:0] io_reg3, 
    output [31:0] io_reg4
);

    // --- Combinational Wires (Cycle 1) ---
    wire [5:0] opcode = ins[31:26];             
    wire [4:0] src1_addr = ins[25:21]; 
    wire [4:0] src2_addr = ins[20:16]; 
    wire [4:0] dest_addr = (opcode == `OP_REG) ? ins[15:11] : ins[20:16]; 
    wire [4:0] shift_amount = ins[10:6];
    wire [5:0] func = ins[5:0];
    wire [15:0] imm = ins[15:0];
    wire [7:0] j_addr = ins[7:0]; // Bottom 8 bits for 256-word memory space

    wire [31:0] src1;              
    wire [31:0] src2;              

    // Extend the immediate value
    wire [31:0] sign_ext_imm = {{16{imm[15]}}, imm}; 
    wire [31:0] zero_ext_imm = {16'b0, imm};         
    
    // Mux for the ALU's second input (Evaluated in Cycle 1)
    wire [31:0] alu_src2 = (opcode == `OP_REG) ? src2 : 
                           ((opcode == `OP_ANDI) || (opcode == `OP_ORI) || (opcode == `OP_XORI)) ? zero_ext_imm : 
                           sign_ext_imm;

    // --- Inter-Stage Registers (Cycle 1 -> Cycle 2) ---
    reg [5:0]  opcode_reg;
    reg [5:0]  func_reg;
    reg [4:0]  shift_amount_reg;
    reg [31:0] src1_reg;
    reg [31:0] src2_reg;          // Registered specifically for BEQ comparison
    reg [31:0] alu_src2_reg;
    reg [4:0]  dest_addr_reg;
    reg [7:0]  j_addr_reg;        // Registered for JUMP instructions
    reg [31:0] sign_ext_imm_reg;  // Registered for BRANCH offsets

    // --- Combinational Wires (Cycle 2) ---
    wire [31:0] dest_data;         
    wire dest_data_valid;          

    // --- Inter-Stage Registers (Cycle 2 -> Cycle 3) ---
    reg [31:0] dest_data_reg;
    reg dest_valid_reg;

    // --- FSM States ---
    reg [1:0] state;
    localparam S_FETCH_READ = 2'd0; // Cycle 1
    localparam S_EXECUTE    = 2'd1; // Cycle 2
    localparam S_WRITEBACK  = 2'd2; // Cycle 3

    // --- System / Control Registers ---
    reg [31:0] io_reg [0:3];       
    reg [1:0] io_reg_index;        
    reg fetched;                   
    reg halt_reg;

    assign halt = halt_reg;
    assign io_reg1 = io_reg[0];
    assign io_reg2 = io_reg[1];
    assign io_reg3 = io_reg[2];
    assign io_reg4 = io_reg[3];

    // --- Structural PC Mathematics (Branch & Jump Support) ---
    wire [31:0] pc_plus_one_32;
    RippleCarryAdder32 pc_adder(
        .A({24'b0, pc}),
        .B(32'd1),
        .Sum(pc_plus_one_32)
    );
    wire [7:0] pc_plus_1 = pc_plus_one_32[7:0];

    wire [31:0] branch_target_32;
    RippleCarryAdder32 branch_adder(
        .A({24'b0, pc_plus_1}),
        .B(sign_ext_imm_reg),
        .Sum(branch_target_32)
    );
    wire [7:0] branch_target = branch_target_32[7:0];

    wire is_equal = (src1_reg == src2_reg);
    reg [7:0] next_pc;

    always @(*) begin
        if (opcode_reg == `OP_J) begin
            next_pc = j_addr_reg;
        end else if (opcode_reg == `OP_BEQ && is_equal) begin
            next_pc = branch_target;
        end else begin
            next_pc = pc_plus_1;
        end
    end

    // --- Module Instantiations ---
    RegisterFile rf (
        src1_addr, 
        src2_addr, 
        src1, 
        src2, 
        dest_addr_reg,     
        dest_data_reg,     
        dest_valid_reg,    
        clk
    );

    ALU alu (
        src1_reg,          
        alu_src2_reg,      
        shift_amount_reg,  
        opcode_reg,        
        func_reg,          
        dest_data,         
        dest_data_valid    
    );

    // --- Sequential Logic (The Three-State FSM) ---
    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'b0;
            io_reg_index <= 2'b0;
            fetched <= 1'b0;
            state <= S_FETCH_READ;
            halt_reg <= 1'b0;
            dest_valid_reg <= 1'b0;
        end
        else begin
            case (state)
                S_FETCH_READ: begin
                    fetched <= 1'b1;
                    if (!halt_reg) begin
                        opcode_reg <= opcode;
                        func_reg <= func;
                        shift_amount_reg <= shift_amount;
                        src1_reg <= src1;
                        src2_reg <= src2; // Must save raw src2 for BEQ comparisons
                        alu_src2_reg <= alu_src2;
                        dest_addr_reg <= dest_addr;
                        j_addr_reg <= j_addr;
                        sign_ext_imm_reg <= sign_ext_imm;
                        
                        state <= S_EXECUTE;
                    end
                end

                S_EXECUTE: begin
                    if (!halt_reg) begin
                        dest_data_reg <= dest_data;
                        dest_valid_reg <= dest_data_valid;
                        
                        if ((opcode_reg == `OP_REG) && (func_reg == `FUNC_SYSCALL) && (src1_reg == `SYS_exit)) begin
                            halt_reg <= 1'b1;
                        end

                        state <= S_WRITEBACK;
                    end
                end

                S_WRITEBACK: begin
                    dest_valid_reg <= 1'b0; 

                    if (!halt_reg) begin
                        pc <= next_pc; // Uses the Branch/Jump logic multiplexer!
                        state <= S_FETCH_READ;
                    end
                end
            endcase
        end
    end

    // --- I/O Syscall Logic (Negedge) ---
    always @(negedge clk) begin
        if (state == S_EXECUTE) begin
            if ((opcode_reg == `OP_REG) && (func_reg == `FUNC_SYSCALL) && (src1_reg == `SYS_write)) begin
                io_reg_index <= io_reg_index + 1;
                io_reg[io_reg_index] <= alu_src2_reg; 
            end
        end
    end

endmodule
