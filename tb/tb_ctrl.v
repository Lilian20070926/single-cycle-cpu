`timescale 1ns/1ps
//------------------------------------------------------------------
// tb_ctrl: control + alucontrol 一起测
//
//   为什么两个模块塞一个 TB：
//   它俩的接口就是 ALUOp 编码，而这里正是最容易出 bug 的地方
//   —— 上面译出 2'b10，下面没接住 / 接成别的。
//   单独测各自的真值表，反而抓不到这种"上下对不上"的问题。
//
//   跑法：
//     iverilog -g2012 -Wall -o build/t_ctrl \
//         rtl/control.v rtl/alucontrol.v tb/tb_ctrl.v
//     vvp build/t_ctrl
//------------------------------------------------------------------
module tb_ctrl;

    reg  [5:0] opcode, funct;
    wire       regdst, alusrc, memtoreg, regwrite, memread, memwrite, branch;
    wire [1:0] aluop;
    wire [3:0] alucontrol;

    integer errors = 0;
    integer ncase  = 0;

    control u_control (
        .opcode   (opcode),
        .regdst   (regdst),
        .alusrc   (alusrc),
        .memtoreg (memtoreg),
        .regwrite (regwrite),
        .memread  (memread),
        .memwrite (memwrite),
        .branch   (branch),
        .aluop    (aluop)
    );

    alucontrol u_alucontrol (
        .aluop      (aluop),
        .funct      (funct),
        .alucontrol (alucontrol)
    );

    // 期望值传 1'bx 表示"这条指令用不到这个信号，不检查"
    // （比如 sw 的 RegDst / MemToReg 本来就是 X，写成 0 或 1 都对）
    task chk;
        input e_regdst, e_alusrc, e_memtoreg, e_regwrite;
        input e_memread, e_memwrite, e_branch;
        input [1:0] e_aluop;
        reg bad;
        begin
            #1;
            ncase = ncase + 1;
            bad = 0;
            if (e_regdst   !== 1'bx && regdst   !== e_regdst)   bad = 1;
            if (e_alusrc   !== 1'bx && alusrc   !== e_alusrc)   bad = 1;
            if (e_memtoreg !== 1'bx && memtoreg !== e_memtoreg) bad = 1;
            if (e_regwrite !== 1'bx && regwrite !== e_regwrite) bad = 1;
            if (e_memread  !== 1'bx && memread  !== e_memread)  bad = 1;
            if (e_memwrite !== 1'bx && memwrite !== e_memwrite) bad = 1;
            if (e_branch   !== 1'bx && branch   !== e_branch)   bad = 1;
            if (aluop !== e_aluop)                              bad = 1;
            if (bad) begin
                errors = errors + 1;
                $display("FAIL control opcode=%b", opcode);
                $display("     期望 rdst=%b src=%b m2r=%b wr=%b rd=%b wm=%b br=%b aluop=%b",
                         e_regdst, e_alusrc, e_memtoreg, e_regwrite,
                         e_memread, e_memwrite, e_branch, e_aluop);
                $display("     实际 rdst=%b src=%b m2r=%b wr=%b rd=%b wm=%b br=%b aluop=%b",
                         regdst, alusrc, memtoreg, regwrite,
                         memread, memwrite, branch, aluop);
            end
        end
    endtask

    task chk_alu;
        input [3:0] e;
        begin
            #1;
            ncase = ncase + 1;
            if (alucontrol !== e) begin
                errors = errors + 1;
                $display("FAIL alucontrol opcode=%b funct=%b aluop=%b 期望 %b 实际 %b",
                         opcode, funct, aluop, e, alucontrol);
            end else
                $display("ok   opcode=%b funct=%b -> alucontrol=%b", opcode, funct, alucontrol);
        end
    endtask

    initial begin
        // ---------------------------------------------------------- control
        opcode = 6'b000000; funct = 6'b100000;
        chk(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 2'b10);   // R 型

        opcode = 6'b100011; funct = 6'b000000;
        chk(1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 2'b00);   // lw

        opcode = 6'b101011; funct = 6'b000000;
        chk(1'bx, 1'b1, 1'bx, 1'b0, 1'b0, 1'b1, 1'b0, 2'b00);   // sw

        opcode = 6'b000100; funct = 6'b000000;
        chk(1'bx, 1'b0, 1'bx, 1'b0, 1'b0, 1'b0, 1'b1, 2'b01);   // beq

        // ---------------------------------------------------------- alucontrol
        // 走完整的 opcode -> aluop -> alucontrol 路径，这才是真实连接关系
        opcode = 6'b100011; funct = 6'b000000; chk_alu(4'b0010);  // lw  -> ADD
        opcode = 6'b101011; funct = 6'b000000; chk_alu(4'b0010);  // sw  -> ADD
        opcode = 6'b000100; funct = 6'b000000; chk_alu(4'b0110);  // beq -> SUB

        opcode = 6'b000000;
        funct  = 6'b100000; chk_alu(4'b0010);                     // add
        funct  = 6'b100010; chk_alu(4'b0110);                     // sub
        funct  = 6'b100100; chk_alu(4'b0000);                     // and
        funct  = 6'b100101; chk_alu(4'b0001);                     // or
        funct  = 6'b101010; chk_alu(4'b0111);                     // slt

        $display("");
        if (errors == 0) $display("*** PASS: %0d 条用例全过 ***", ncase);
        else             $display("*** FAIL: %0d / %0d 条不符 ***", errors, ncase);
        $finish;
    end

endmodule
