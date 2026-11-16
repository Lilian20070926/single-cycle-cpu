# t_mem.asm -- 只测 lw / sw
# 目的：lw 读出 -> sw 写回另一个地址 -> 再 lw 读回来。
#       一趟走完，同时验证 dmem 的读、写、地址对齐。
# 跑法：make sim PROG=t_mem

.data
.word 0x11223344      # DM[0]
.word 0x00000000      # DM[1] 留给 sw

.text
        lw   $t0, 0($zero)      # t0 = 0x11223344
        sw   $t0, 4($zero)      # DM[1] = 0x11223344
        lw   $t1, 4($zero)      # t1 = 0x11223344  (读回来)
        .halt

.expect reg $t0 0x11223344
.expect reg $t1 0x11223344
.expect mem 1 0x11223344
