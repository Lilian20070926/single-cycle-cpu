# prog2.asm -- beq 循环 + 负数偏移
# 没有 addi 怎么自增? 把常数 1 预置进 DMEM, 用 lw 读出来, 再用 add 加。
# 这个程序算 1+2+3+4+5 = 15。

.data
.word 0x00000005      # DM[0] = 5, 循环次数
.word 0x00000001      # DM[1] = 1, 常数 1
.word 0x00000000      # DM[2] 留给 sw 写结果

.text
        lw   $t0, 0($zero)      # t0 = 5   剩余次数
        lw   $t1, 4($zero)      # t1 = 1   常数 1
        add  $t2, $zero, $zero  # t2 = 0   累加和
        add  $t3, $zero, $zero  # t3 = 0   当前加数
loop:
        add  $t3, $t3, $t1      # t3 += 1
        add  $t2, $t2, $t3      # t2 += t3
        sub  $t0, $t0, $t1      # t0 -= 1
        beq  $t0, $zero, done   # 减到 0 就出循环
        beq  $zero, $zero, loop # 无条件跳(backward, 偏移是负数)
done:
        sw   $t2, 8($zero)      # DM[2] = 15
        .halt

# ---- 期望终态 ----
.expect reg $t0 0
.expect reg $t1 1
.expect reg $t2 15
.expect reg $t3 5
.expect mem 2 15
