`timescale 1ns/1ps
//------------------------------------------------------------------
// regfile: 32 x 32 寄存器堆
//   两个组合读口，一个上升沿写口
//   tb 用层次引用读 regs 做终态比对，所以数组名必须叫 regs
//------------------------------------------------------------------
module regfile (
    input  wire        clk,
    input  wire        we,        // 写使能
    input  wire [4:0]  ra1,       // 读地址 1
    input  wire [4:0]  ra2,       // 读地址 2
    input  wire [4:0]  wa,        // 写地址
    input  wire [31:0] wd,        // 写数据
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] regs [0:31];

    // TODO: rd1 / rd2 组合读
    //       $zero 恒等于 0 —— 读的时候也要保证读到 0
    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];

    // TODO: 上升沿写
    //         if (we && wa != 5'd0) regs[wa] <= wd;
    always @(posedge clk) begin
        if (we && (wa != 5'd0)) begin // $zero(0号寄存器)禁止写入
            regs[wa] <= wd;
        end
    end

endmodule

