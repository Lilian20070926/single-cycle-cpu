`timescale 1ns/1ps
//------------------------------------------------------------------
// tb_cpu: 顶层测试台
//
//   用法（在工程根目录执行）:
//     vvp build/sim +IMEM=test/prog1.imem.hex \
//                   +DMEM=test/prog1.dmem.hex \
//                   +EXPECT=test/prog1.expect
//   不带参数时默认用 prog1，所以 make sim 已经帮你传好了。
//
//   它做三件事:
//     1. 把机器码 / 初始数据装进 imem / dmem
//     2. 一直跑到 PC 连续两拍不变（认为撞上 .halt 的原地自旋）
//     3. 打印终态，跟 .expect 文件逐项比对，给出 PASS / FAIL
//------------------------------------------------------------------
module tb_cpu;

    // ---------------------------------------------------------------- 时钟 / 复位
    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;              // 周期 10ns

    // ---------------------------------------------------------------- 文件名
    // 用 reg 装字符串是 iverilog 的常见写法，比 SV 的 string 更保险
    reg [8*128:1] f_imem;
    reg [8*128:1] f_dmem;
    reg [8*128:1] f_expect;

    // ---------------------------------------------------------------- DUT
    cpu_top dut (
        .clk (clk),
        .rst (rst)
    );

    // ---------------------------------------------------------------- 运行参数
    localparam integer MAX_CYCLES = 500;

    integer    cycles;
    reg [31:0] pc_prev;
    reg        halted;
    integer    i, errors, ncheck, fd, kind, idx, nx;
    reg [31:0] expect_val;
    reg        xfail;

    // ---------------------------------------------------------------- 波形
    initial begin
        $dumpfile("build/dump.vcd");    // 目录不存在时不会生成，记得 mkdir -p build
        $dumpvars(0, tb_cpu);
    end

    // ---------------------------------------------------------------- 主流程
    initial begin
        // 1) 装载机器码和初始数据。
        //    这是层次引用，路径写死在这里，所以 rtl 里实例名不能改：
        //    datapath 里必须叫 u_imem / u_dmem，数组必须叫 mem
        if (!$value$plusargs("IMEM=%s", f_imem))     f_imem   = "test/prog1.imem.hex";
        if (!$value$plusargs("DMEM=%s", f_dmem))     f_dmem   = "test/prog1.dmem.hex";
        if (!$value$plusargs("EXPECT=%s", f_expect)) f_expect = "test/prog1.expect";

        $readmemh(f_imem, dut.u_datapath.u_imem.mem);
        $readmemh(f_dmem, dut.u_datapath.u_dmem.mem);

        // 2) 复位两拍，然后在下降沿撤掉复位，让第一个有效周期完整
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 0;

        if (^dut.u_datapath.u_pc.pc === 1'bx)
            $display("!! PC 是 x —— pc.v 还没写，或者复位没接对");

        // 2.5) 体检：复位刚撤掉、第一条指令还没执行时看这三行。
        //      整个仿真里最值得看的就这三行 —— 数据通路通没通，一眼就知道。
        #1;
        $display("--- 复位后体检 ---");
        $display("  pc     = 0x%08h", dut.u_datapath.u_pc.pc);
        $display("  instr  = 0x%08h", dut.u_datapath.u_imem.instr);
        if (dut.u_datapath.u_imem.instr === 32'd0)
            $display("  !! instr 恒为 0 -> imem 没读出数据：还是占位代码？字索引写成 addr 了？");
        if (^dut.u_datapath.u_imem.instr === 1'bx)
            $display("  !! instr 是 x -> $readmemh 没生效，或者 imem 的输出没接到 instr");

        // 3) 跑到停机。
        //    pc_prev 初值故意给一个 PC 不可能取到的值，避免第一拍就误判停机
        cycles  = 0;
        halted  = 0;
        xfail   = 0;
        pc_prev = 32'hDEAD_BEEF;
        while (!halted && cycles < MAX_CYCLES) begin
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if (^dut.u_datapath.u_pc.pc === 1'bx) begin
                $display("");
                $display("!! 第 %0d 拍 PC 变成了 x，仿真提前结束。", cycles);
                $display("   这一定是数据通路里有信号没赋值。按这个顺序查：");
                $display("     1) instr 是 x        -> imem 装载 / addr[9:2] 索引");
                $display("     2) rd1/rd2 是 x      -> 读了一个从没被写过的寄存器");
                $display("     3) alu_result 是 x   -> alucontrol 没译出来");
                $display("     4) 控制信号是 x      -> control 某个分支没把 8 个信号赋全");
                halted = 1;
                xfail  = 1;
            end
            else if (dut.u_datapath.u_pc.pc === pc_prev) halted = 1;
            else                                        pc_prev = dut.u_datapath.u_pc.pc;
        end

        if (!xfail && !halted)
            $display("\n!! 跑满 %0d 拍还没停机 —— 可能死循环，也可能 PC 压根没在往前走", MAX_CYCLES);

        // 4) 打印终态
        $display("");
        $display("================= 终态（跑了 %0d 拍） =================", cycles);
        $display("PC = 0x%08h", dut.u_datapath.u_pc.pc);

        $display("--- 寄存器（只列非 0 且已知的） ---");
        nx = 0;
        for (i = 1; i < 32; i = i + 1) begin
            if (^dut.u_datapath.u_regfile.regs[i] === 1'bx)
                nx = nx + 1;                    // 程序从没写过的寄存器
            else if (dut.u_datapath.u_regfile.regs[i] !== 32'd0)
                $display("  reg[%0d] = 0x%08h  (%0d)",
                         i,
                         dut.u_datapath.u_regfile.regs[i],
                         dut.u_datapath.u_regfile.regs[i]);
        end
        if (nx > 0)
            $display("  （另有 %0d 个寄存器从没被写过，值是 x，这是正常的）", nx);

        // regs[0] 因为写口有保护，永远是 x —— 只有它变成"已知的非 0"才是真 bug
        if (^dut.u_datapath.u_regfile.regs[0] !== 1'bx &&
            dut.u_datapath.u_regfile.regs[0] !== 32'd0)
            $display("  !! $zero 不是 0，说明写口没保护 wa != 0");

        $display("--- 内存前 8 个字 ---");
        for (i = 0; i < 8; i = i + 1)
            $display("  DM[%0d] = 0x%08h", i, dut.u_datapath.u_dmem.mem[i]);

        // 5) 自检
        errors = 0;
        ncheck = 0;
        fd = $fopen(f_expect, "r");
        if (xfail) begin
            $display("\n（PC 已经变成 x，自检跳过）");
            if (fd != 0) $fclose(fd);
        end else if (fd == 0) begin
            $display("\n!! 打不开期望文件，跳过自检。先跑 make asm 生成它。");
        end else begin
            $display("--- 自检 ---");
            while ($fscanf(fd, "%d %d %h", kind, idx, expect_val) == 3) begin
                ncheck = ncheck + 1;
                if (kind == 0) begin
                    if (dut.u_datapath.u_regfile.regs[idx] !== expect_val) begin
                        errors = errors + 1;
                        $display("  FAIL reg[%0d] 期望 0x%08h 实际 0x%08h",
                                 idx, expect_val, dut.u_datapath.u_regfile.regs[idx]);
                    end else
                        $display("  ok   reg[%0d] = 0x%08h", idx, expect_val);
                end else begin
                    if (dut.u_datapath.u_dmem.mem[idx] !== expect_val) begin
                        errors = errors + 1;
                        $display("  FAIL DM[%0d] 期望 0x%08h 实际 0x%08h",
                                 idx, expect_val, dut.u_datapath.u_dmem.mem[idx]);
                    end else
                        $display("  ok   DM[%0d] = 0x%08h", idx, expect_val);
                end
            end
            $fclose(fd);

            if (ncheck == 0)
                $display("  （期望文件是空的，没有可比对的项）");
            else if (errors == 0)
                $display("\n  *** PASS: %0d 项全部匹配 ***", ncheck);
            else
                $display("\n  *** FAIL: %0d / %0d 项不符 ***", errors, ncheck);
        end
        $display("======================================================");
        $finish;
    end

endmodule
