`timescale 1ns/1ps
//------------------------------------------------------------------
// tb_regfile: 寄存器堆单模块测试
//   重点查两件 lint 看不见的事：
//     1. we=0 时到底写不写
//     2. 往 $zero 写会不会把它写坏
//
//   跑法：
//     iverilog -g2012 -Wall -o build/t_regfile rtl/regfile.v tb/tb_regfile.v
//     vvp build/t_regfile
//------------------------------------------------------------------
module tb_regfile;

    reg         clk = 0;
    reg         we  = 0;
    reg  [4:0]  ra1 = 0, ra2 = 0, wa = 0;
    reg  [31:0] wd  = 0;
    wire [31:0] rd1, rd2;

    integer errors = 0;
    integer ncase  = 0;

    regfile dut (
        .clk (clk),
        .we  (we),
        .ra1 (ra1),
        .ra2 (ra2),
        .wa  (wa),
        .wd  (wd),
        .rd1 (rd1),
        .rd2 (rd2)
    );

    always #5 clk = ~clk;

    task chk;
        input [31:0] e1, e2;
        begin
            #1;
            ncase = ncase + 1;
            if (rd1 !== e1 || rd2 !== e2) begin
                errors = errors + 1;
                $display("FAIL ra1=%0d ra2=%0d 期望 rd1=%08h rd2=%08h 实际 %08h %08h",
                         ra1, ra2, e1, e2, rd1, rd2);
            end else
                $display("ok   ra1=%0d -> %08h   ra2=%0d -> %08h", ra1, rd1, ra2, rd2);
        end
    endtask

    // 等一个上升沿把数据写进去
    task wr;
        input [4:0]  a;
        input [31:0] d;
        begin
            wa = a; wd = d; we = 1'b1;
            @(posedge clk);
            #1;
            we = 1'b0;
        end
    endtask

    initial begin
        // 用例 1: 写一个寄存器再读回来（顺手验证 $zero 读到 0）
        wr(5'd8, 32'h1234_5678);
        ra1 = 8; ra2 = 0;
        chk(32'h1234_5678, 32'd0);

        // 用例 2: 两个读口同时读不同寄存器
        wr(5'd9, 32'h0000_ABCD);
        ra1 = 8; ra2 = 9;
        chk(32'h1234_5678, 32'h0000_ABCD);

        // 用例 3: we=0 时写不进去
        wa = 9; wd = 32'hFFFF_FFFF; we = 1'b0;
        @(posedge clk);
        #1;
        ra1 = 9; ra2 = 0;
        chk(32'h0000_ABCD, 32'd0);

        // 用例 4: 往 $zero 写，必须写不进去
        wr(5'd0, 32'hFFFF_FFFF);
        ra1 = 0; ra2 = 1;
        chk(32'd0, 32'hxxxx_xxxx);      // reg[1] 从没写过, 还是 x

        // 用例 5: 层次检查 regs[0] 本身有没有被写（读口兜住只是第二道防线）
        ncase = ncase + 1;
        if (dut.regs[0] !== 32'hxxxx_xxxx && dut.regs[0] !== 32'd0) begin
            errors = errors + 1;
            $display("FAIL regs[0] 被写坏了: 0x%08h", dut.regs[0]);
        end else
            $display("ok   regs[0] 没被写坏");

        $display("");
        if (errors == 0) $display("*** PASS: %0d 条用例全过 ***", ncase);
        else             $display("*** FAIL: %0d / %0d 条不符 ***", errors, ncase);
        $finish;
    end

endmodule
