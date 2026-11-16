# t_rtype.asm -- 只测 R 型五条（add sub and or slt），外加必要的 lw
# 目的：prog1 挂了的时候，先用这个判断是不是 ALU / funct 译码的问题。
# 跑法：make sim PROG=t_rtype

.data
.word 0x00000005      # DM[0] = 5
.word 0x00000003      # DM[1] = 3

.text
        lw   $t0, 0($zero)      # t0 = 5
        lw   $t1, 4($zero)      # t1 = 3

        add  $s0, $t0, $t1      # s0 = 8
        sub  $s1, $t0, $t1      # s1 = 2
        and  $s2, $t0, $t1      # s2 = 1
        or   $s3, $t0, $t1      # s3 = 7
        slt  $s4, $t1, $t0      # s4 = 1   (3 < 5)
        slt  $s5, $t0, $t1      # s5 = 0   (5 < 3)

        .halt

.expect reg $s0 8
.expect reg $s1 2
.expect reg $s2 1
.expect reg $s3 7
.expect reg $s4 1
.expect reg $s5 0
