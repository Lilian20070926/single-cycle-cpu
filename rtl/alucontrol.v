`timescale 1ns/1ps
//------------------------------------------------------------------
// alucontrol: 第二级译码
//   根据 ALUOp 和 funct 决定 ALU 做哪种运算
//------------------------------------------------------------------
module alucontrol (
    input  wire [1:0] aluop,
    input  wire [5:0] funct,
    output reg  [3:0] alucontrol
);

    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // TODO: 两级译码
    //         aluop == 2'b00 -> ALU_ADD  (lw/sw 算地址)
    //         aluop == 2'b01 -> ALU_SUB  (beq 比较)
    //         aluop == 2'b10 -> 看 funct 决定
    //                            100000 add / 100010 sub / 100100 and
    //                            100101 or  / 101010 slt
always @(*) begin
        case (aluop)
            2'b00: alucontrol = ALU_ADD;                     // lw sw，做加法算地址
            2'b01: alucontrol = ALU_SUB;                     // beq，做减法比较
            2'b10: begin                                     // R型指令，查funct字段
                case (funct)
                    6'b100000: alucontrol = ALU_ADD;        // add
                    6'b100010: alucontrol = ALU_SUB;        // sub
                    6'b100100: alucontrol = ALU_AND;        // and
                    6'b100101: alucontrol = ALU_OR;         // or
                    6'b101010: alucontrol = ALU_SLT;        // slt
                    default:   alucontrol = 4'b0000;         // 不会出现，避免锁存
                endcase
            end
            default: alucontrol = 4'b0000;                   // 其他aluop，防止锁存
        endcase
    end
endmodule
