`timescale 1ns/1ps
//------------------------------------------------------------------
// datapath: 数据通路
//   除了 PC 和 regfile 的写口，这里面全是组合逻辑，没有别的时序块。
//
//   注意：tb 靠层次引用读内部信号，下面这些实例名和数组名不能改：
//       u_pc.pc            -> tb 用它检测停机
//       u_regfile.regs[]   -> tb 用它比对终态
//       u_dmem.mem[]       -> tb 用它装载数据 / 比对终态
//       u_imem.mem[]       -> tb 用它装载机器码
//------------------------------------------------------------------
module datapath (
    input  wire        clk,
    input  wire        rst,
    // ---- 来自 control 的控制信号 ----
    input  wire        regdst,
    input  wire        alusrc,
    input  wire        memtoreg,
    input  wire        regwrite,
    input  wire        memread,
    input  wire        memwrite,
    input  wire        branch,
    input  wire [1:0]  aluop,
    // ---- 送给 control 的译码输入 ----
    output wire [5:0]  opcode
);

    // ---------------------------------------------------------------
    // 内部信号
    // ---------------------------------------------------------------
    wire [31:0] pc, pc_plus4, pc_next;
    wire [31:0] instr;
    wire [5:0]  funct;
    wire [4:0]  rs, rt, rd, wr_addr;
    wire [15:0] imm16;
    wire [31:0] imm32;
    wire [31:0] rf_rd1, rf_rd2, alu_a, alu_b, alu_result, wr_data;
    wire [31:0] dmem_rdata;
    wire [3:0]  alucontrol;
    wire        zero, pcsrc;

    // 指令字段拆分
    assign opcode  = instr[31:26];
    assign rs      = instr[25:21];
    assign rt      = instr[20:16];
    assign rd      = instr[15:11];
    assign funct   = instr[5:0];
    assign imm16   = instr[15:0];

    // 关键多路选择 & 逻辑（文档四条关键连线）
    assign wr_addr  = regdst   ? rd   : rt;
    assign alu_b    = alusrc   ? imm32 : rf_rd2;
    assign wr_data  = memtoreg ? dmem_rdata : alu_result;
    assign pcsrc    = branch & zero;

    // PC+4 顺序地址；分支目标：pc_plus4 + (imm32 << 2)
    assign pc_plus4 = pc + 32'd4;
    assign pc_next  = pcsrc ? (pc_plus4 + (imm32 << 2)) : pc_plus4;

    assign alu_a    = rf_rd1;  // alu_a固定接读端口1

    //----------------------------------------------------------------
    // 模块实例化，实例名字严格不能修改！tb做层次读取依赖这些名字
    //----------------------------------------------------------------
    pc u_pc (
        .clk(clk),
        .rst(rst),
        .pc_next(pc_next),
        .pc(pc)
    );

    imem u_imem (
        .addr(pc),
        .instr(instr)
    );

    regfile u_regfile (
        .clk(clk),
        .we(regwrite),
        .ra1(rs),
        .ra2(rt),
        .wa(wr_addr),
        .wd(wr_data),
        .rd1(rf_rd1),
        .rd2(rf_rd2)
    );

    signext u_signext (
        .imm16(imm16),
        .imm32(imm32)
    );

    alu u_alu (
        .a(alu_a),
        .b(alu_b),
        .alucontrol(alucontrol),
        .result(alu_result),
        .zero(zero)
    );

    alucontrol u_alucontrol (
        .aluop(aluop),
        .funct(funct),
        .alucontrol(alucontrol)
    );

    dmem u_dmem (
        .clk(clk),
        .memread(memread),
        .memwrite(memwrite),
        .addr(alu_result),
        .wdata(rf_rd2),
        .rdata(dmem_rdata)
    );

endmodule

