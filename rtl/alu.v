`timescale 1ns/1ps
//------------------------------------------------------------------
// alu: 算术逻辑单元
//   alucontrol 编码见 docs/design.txt
//------------------------------------------------------------------
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alucontrol,
    output reg  [31:0] result,
    output wire        zero
);

    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // TODO: case (alucontrol) 实现五种运算
    //       - sub 是 a + ~b + 1，别漏了那个 +1
    //       - slt 必须是有符号比较，用 $signed(a) 和 $signed(b)
always @(*) begin
        case (alucontrol)
            ALU_AND: result = a & b;
            ALU_OR:  result = a | b;
            ALU_ADD: result = a + b;
            ALU_SUB: result = a + (~b) + 32'd1;   // 减法：a - b = a + ~b +1
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;              // 其他情况输出0，避免latches
        endcase
    end
    // zero 用来给 beq 判断相等（ALU 做减法，结果为 0 就相等）
    assign zero = (result == 32'd0);

endmodule
