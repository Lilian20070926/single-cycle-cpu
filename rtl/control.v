`timescale 1ns/1ps
//------------------------------------------------------------------
// control: 主译码器
//   opcode -> 8 个控制信号，真值表见 docs/design.txt
//------------------------------------------------------------------
module control (
    input  wire [5:0]  opcode,
    output reg         regdst,
    output reg         alusrc,
    output reg         memtoreg,
    output reg         regwrite,
    output reg         memread,
    output reg         memwrite,
    output reg         branch,
    output reg  [1:0]  aluop
);

    // opcode 编码
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_BEQ   = 6'b000100;

    // TODO: 一个 case (opcode) 把 8 个信号都赋上值
    //       注意每个分支都要把 8 个信号写全，别漏，否则综合出锁存器
    //       R 型里 add/sub/and/or/slt 这 5 条控制信号完全一样，区别在 funct
    //       （funct 由 alucontrol 处理，这里不用管）
always @(*) begin
        case(opcode)
            // R‑型指令 add sub and or slt
            OP_RTYPE: begin
                regdst    = 1'b1;
                alusrc    = 1'b0;
                memtoreg  = 1'b0;
                regwrite  = 1'b1;
                memread   = 1'b0;
                memwrite  = 1'b0;
                branch    = 1'b0;
                aluop     = 2'b10;
            end
            // lw 加载字
            OP_LW: begin
                regdst    = 1'b0;
                alusrc    = 1'b1;
                memtoreg  = 1'b1;
                regwrite  = 1'b1;
                memread   = 1'b1;
                memwrite  = 1'b0;
                branch    = 1'b0;
                aluop     = 2'b00;
            end
            // sw 存储字
            OP_SW: begin
                regdst    = 1'b0;  // X，无关，填0
                alusrc    = 1'b1;
                memtoreg  = 1'b0;  // X，无关，填0
                regwrite  = 1'b0;
                memread   = 1'b0;
                memwrite  = 1'b1;
                branch    = 1'b0;
                aluop     = 2'b00;
            end
            // beq 相等分支
            OP_BEQ: begin
                regdst    = 1'b0;  // X，无关，填0
                alusrc    = 1'b0;
                memtoreg  = 1'b0;  // X，无关，填0
                regwrite  = 1'b0;
                memread   = 1'b0;
                memwrite  = 1'b0;
                branch    = 1'b1;
                aluop     = 2'b01;
            end
            // 默认：全部置0，防止锁存
            default: begin
                regdst    = 1'b0;
                alusrc    = 1'b0;
                memtoreg  = 1'b0;
                regwrite  = 1'b0;
                memread   = 1'b0;
                memwrite  = 1'b0;
                branch    = 1'b0;
                aluop     = 2'b00;
            end
        endcase
    end
endmodule
