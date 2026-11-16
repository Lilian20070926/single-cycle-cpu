# t_edge.asm -- 边界情况，补 prog1 的盲区
#
# prog1 里有两处没测到：
#   1. slt 只测了正数（3<5、5<3），负数比大小的有符号性从没在系统级验证过
#   2. 所有 R 型的 rd/rs/rt 都不同，没测过"同一条指令读写同一个寄存器"
#
# 跑法：make sim PROG=t_edge

.data
.word 0x00000005      # DM[0] = 5
.word 0x00000003      # DM[1] = 3

.text
        lw   $t0, 0($zero)      # t0 = 5
        lw   $t1, 4($zero)      # t1 = 3

        # ---- 1) 同寄存器读写：rd == rs == rt ----
        # 必须读到"旧值"再写回。若实现成先写后读，t0 会变成 25 而不是 20
        add  $t0, $t0, $t0      # t0 = 5 + 5  = 10
        add  $t0, $t0, $t0      # t0 = 10 + 10 = 20

        # ---- 2) $zero 当目的寄存器：写口应忽略 ----
        # 读口有兜底，所以从 .expect 看不出差别；
        # 真正验证 regs[0] 没被写坏是 tb_regfile.v 的事。
        # 这里只确认它不会把别的东西搞乱。
        add  $zero, $t0, $t1    # 23 应该被丢掉

        # ---- 3) slt 负数：有符号比较 ----
        sub  $t2, $zero, $t0    # t2 = -20 = 0xffffffec
        slt  $s0, $t2, $zero    # s0 = 1   (-20 < 0 为真)
        slt  $s1, $zero, $t2    # s1 = 0   (0 < -20 为假)
        #   若 slt 写成无符号比较，第一条会给 0、第二条会给 1，两条同时挂

        .halt

.expect reg $t0 20
.expect reg $t2 0xffffffec
.expect reg $s0 1
.expect reg $s1 0
