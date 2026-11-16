# prog1.asm -- 8 条指令全覆盖的功能测试
# 做法: 先把常数放进 DMEM, 用 lw 读进寄存器, 再用 8 条指令各自算一遍,
#       最后用 beq 的 taken / not-taken 两条路径验证跳转。
# 期望终态写在下面的 .expect 里, 会自动生成 prog1.expect 给 tb_cpu.v 比对。

.data
.word 0x00000005      # DM[0] = 5
.word 0x00000003      # DM[1] = 3
.word 0x00000001      # DM[2] = 1   <- 常数 1, 没有 addi 时靠它自增
.word 0x00000000      # DM[3] 空着, 留给 sw 写结果

.text
        lw   $t0, 0($zero)      # t0 = 5
        lw   $t1, 4($zero)      # t1 = 3
        lw   $t2, 8($zero)      # t2 = 1

        add  $s0, $t0, $t1      # s0 = 8
        sub  $s1, $t0, $t1      # s1 = 2
        and  $s2, $t0, $t1      # s2 = 5 & 3 = 1
        or   $s3, $t0, $t1      # s3 = 5 | 3 = 7
        slt  $s4, $t1, $t0      # s4 = 1   (3 < 5)
        slt  $s5, $t0, $t1      # s5 = 0   (5 < 3)

        sw   $s0, 12($zero)     # DM[3] = 8

        add  $s7, $zero, $zero  # s7 = 0   预置：被跳过时才看得出"真的没被改"
        beq  $t0, $t1, bad      # 不相等 -> 不跳, 下一条应被执行
        add  $s6, $zero, $t2    # s6 = 1   (说明 beq 没有误跳)
        beq  $t0, $t0, ok       # 相等 -> 跳, 下一条应被跳过
        add  $s7, $zero, $t2    # 被跳过, s7 应保持 0
ok:
        .halt
bad:
        .halt

# ---- 期望终态 ----
.expect reg $t0 5
.expect reg $t1 3
.expect reg $t2 1
.expect reg $s0 8
.expect reg $s1 2
.expect reg $s2 1
.expect reg $s3 7
.expect reg $s4 1
.expect reg $s5 0
.expect reg $s6 1
.expect reg $s7 0
.expect mem 3 8
