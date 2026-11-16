`timescale 1ns/1ps
//------------------------------------------------------------------
// PC: 32 位程序计数器
//   rst 有效 -> 清零; 否则每个上升沿装入 pc_next
//------------------------------------------------------------------
module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);

    // TODO: 一个 always @(posedge clk) 就够了
    //         if (rst) pc <= 32'd0;
    //         else     pc <= pc_next;
always @(posedge clk) begin
        if(rst) begin
            pc <= 32'd0;
        end else begin
            pc <= pc_next;
        end
    end
endmodule
