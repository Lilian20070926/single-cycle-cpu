# t_beq.asm -- 只测 beq 的 taken / not-taken / 向前跳
# 目的：prog1 挂了但 t_rtype 和 t_mem 都过了，问题就在 PC / 分支这里。
#       向后跳（负数偏移）由 prog2 负责，这里不重复。
# 跑法：make sim PROG=t_beq

.data
.word 0x00000005      # DM[0] = 5
.word 0x00000001      # DM[1] = 1

.text
        lw   $t0, 0($zero)      # t0 = 5
        lw   $t1, 4($zero)      # t1 = 1
        add  $s1, $zero, $zero  # s1 = 0   被跳过时的见证值

        beq  $t0, $t1, bad      # 5 != 1, 不跳
        add  $s0, $zero, $t1    # s0 = 1   (执行了 -> 说明没误跳)
        beq  $t0, $t0, fwd      # 相等, 向前跳
        add  $s1, $zero, $t1    # 被跳过 -> s1 保持 0

fwd:
        sw   $s0, 8($zero)      # DM[2] = 1
        .halt

bad:
        add  $s3, $zero, $t1    # 永远不该到这里
        .halt

.expect reg $s0 1
.expect reg $s1 0
.expect mem 2 1
