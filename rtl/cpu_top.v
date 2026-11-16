`timescale 1ns/1ps
//------------------------------------------------------------------
// cpu_top: 顶层 = datapath + control
//   对外只有 clk / rst 两个口，不上板所以不需要别的。
//   tb 例化的是 cpu_top dut (...)，实例名 u_datapath / u_control 别改。
//------------------------------------------------------------------
module cpu_top (
    input  wire clk,
    input  wire rst
);

    // control 和 datapath 之间的控制信号
    wire        regdst;
    wire        alusrc;
    wire        memtoreg;
    wire        regwrite;
    wire        memread;
    wire        memwrite;
    wire        branch;
    wire [1:0]  aluop;
    wire [5:0]  opcode;

    // TODO: 例化两个模块，把上面的线连上
    //
    //   control  u_control  ( .opcode(opcode), .regdst(regdst), ... );
    //   datapath u_datapath ( .clk(clk), .rst(rst), .opcode(opcode),
    //                         .regdst(regdst), ... );
datapath u_datapath (
    .clk(clk),
    .rst(rst),
    .regdst(regdst),
    .alusrc(alusrc),
    .memtoreg(memtoreg),
    .regwrite(regwrite),
    .memread(memread),
    .memwrite(memwrite),
    .branch(branch),
    .aluop(aluop),
    .opcode(opcode)
);

control u_control (
    .opcode(opcode),
    .regdst(regdst),
    .alusrc(alusrc),
    .memtoreg(memtoreg),
    .regwrite(regwrite),
    .memread(memread),
    .memwrite(memwrite),
    .branch(branch),
    .aluop(aluop)
);
endmodule
