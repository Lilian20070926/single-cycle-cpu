`timescale 1ns/1ps
//------------------------------------------------------------------
// tb_alu: 单个模块的 mini testbench 范例
//   其余模块（regfile / control / alucontrol ...）照这个模式自己写，
//   别攒到顶层一起调。
//
//   跑法（在工程根目录）:
//     iverilog -g2012 -Wall -o /tmp/t_alu rtl/alu.v tb/tb_alu.v
//     vvp /tmp/t_alu
//------------------------------------------------------------------
module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  alucontrol;
    wire [31:0] result;
    wire        zero;

    reg  [31:0] er;          // 期望 result
    reg         ez;          // 期望 zero
    integer     errors = 0;
    integer     ncase  = 0;

    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    alu dut (
        .a          (a),
        .b          (b),
        .alucontrol (alucontrol),
        .result     (result),
        .zero       (zero)
    );

    task chk;
        begin
            #1;
            ncase = ncase + 1;
            if (result !== er || zero !== ez) begin
                errors = errors + 1;
                $display("FAIL alucontrol=%b a=%08h b=%08h | 期望 %08h/z%0d, 实际 %08h/z%0d",
                         alucontrol, a, b, er, ez, result, zero);
            end else
                $display("ok   alucontrol=%b a=%08h b=%08h -> %08h z=%0d",
                         alucontrol, a, b, result, zero);
        end
    endtask

    initial begin
        // ---- add ----
        a = 32'd5; b = 32'd3; alucontrol = ALU_ADD; er = 32'd8;  ez = 1'b0; chk;

        // ---- sub ----
        a = 32'd5; b = 32'd3; alucontrol = ALU_SUB; er = 32'd2;  ez = 1'b0; chk;
        a = 32'd5; b = 32'd5; alucontrol = ALU_SUB; er = 32'd0;  ez = 1'b1; chk;   // zero 标志
        a = 32'd3; b = 32'd5; alucontrol = ALU_SUB; er = -32'd2; ez = 1'b0; chk;   // 负数结果

        // ---- and / or ----
        a = 32'd5; b = 32'd3; alucontrol = ALU_AND; er = 32'd1;  ez = 1'b0; chk;
        a = 32'd5; b = 32'd3; alucontrol = ALU_OR;  er = 32'd7;  ez = 1'b0; chk;

        // ---- slt: 重点是有符号 ----
        a = 32'd3;  b = 32'd5; alucontrol = ALU_SLT; er = 32'd1; ez = 1'b0; chk;
        a = 32'd5;  b = 32'd3; alucontrol = ALU_SLT; er = 32'd0; ez = 1'b1; chk;
        a = -32'sd1; b = 32'sd1; alucontrol = ALU_SLT; er = 32'd1; ez = 1'b0; chk;
        //   上面这条是关键：-1 < 1 应该是真。用无符号比较会得到 0，专门抓这个 bug。
        a = 32'sd1; b = -32'sd1; alucontrol = ALU_SLT; er = 32'd0; ez = 1'b1; chk;

        // ---- 结果汇总 ----
        $display("");
        if (errors == 0) $display("*** PASS: %0d 条用例全过 ***", ncase);
        else             $display("*** FAIL: %0d / %0d 条不符 ***", errors, ncase);
        $finish;
    end

endmodule
