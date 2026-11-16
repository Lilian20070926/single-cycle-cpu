`timescale 1ns/1ps
//------------------------------------------------------------------
// dmem: 数据存储器
//   组合读 + 上升沿写。tb 用层次引用往 mem 里 $readmemh，数组名别改。
//------------------------------------------------------------------
module dmem (
    input  wire        clk,
    input  wire        memread,    // 本工程用组合读，这个信号用不用都行
    input  wire        memwrite,
    input  wire [31:0] addr,       // 字节地址
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);

    // 256 个字 = 1KB
    reg [31:0] mem [0:255];

    // TODO: 组合读，字索引是 addr[9:2]
assign rdata = mem[addr[9:2]];
    // TODO: 上升沿写
    //         if (memwrite) mem[addr[9:2]] <= wdata;
always @(posedge clk) begin
        if(memwrite) begin
            mem[addr[9:2]] <= wdata;
        end
    end
endmodule
