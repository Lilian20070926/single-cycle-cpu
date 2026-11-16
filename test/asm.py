#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
极简 MIPS 子集汇编器 —— 只支持本工程的 8 条指令，够用就行。

用法:
    python3 test/asm.py test/prog1.asm

输入 prog1.asm，在同一个目录下生成三个文件:
    prog1.imem.hex    指令存储器初始化 (喂给 $readmemh)
    prog1.dmem.hex    数据存储器初始化
    prog1.expect      期望终态 (给 tb_cpu.v 自检用)

语法:
    .data                    进入数据段
    .word 5                  数据段里放一个 32 位字，从 DMEM 地址 0 开始往上排
    .text                    进入代码段
    label:                   标签。代码段里的地址是字节地址，第一条指令在 0
    add $rd, $rs, $rt        sub / and / or / slt 同理
    lw  $rt, imm($rs)
    sw  $rt, imm($rs)
    beq $rs, $rt, label      第三个数也可以直接写偏移(指令条数)
    .halt                    伪指令 = beq $zero,$zero,-1，原地自旋当停机
    .expect reg $s0 8        声明期望终态: 程序跑完 $s0 应该等于 8
    .expect mem 3 8          声明期望终态: DMEM 第 3 个字应该等于 8
    # 井号是注释，大小写不敏感

寄存器: $zero $at $v0-$v1 $a0-$a3 $t0-$t9 $s0-$s7 $k0-$k1 $gp $sp $fp $ra
        也可以直接写编号 $0 ~ $31
"""

import os
import re
import sys

# ---------------------------------------------------------------- 基础表

_REG_NAMES = [
    'zero', 'at', 'v0', 'v1', 'a0', 'a1', 'a2', 'a3',
    't0', 't1', 't2', 't3', 't4', 't5', 't6', 't7',
    's0', 's1', 's2', 's3', 's4', 's5', 's6', 's7',
    't8', 't9', 'k0', 'k1', 'gp', 'sp', 'fp', 'ra',
]

REG = {}
for _i, _n in enumerate(_REG_NAMES):
    REG['$' + _n] = _i
    REG['$' + str(_i)] = _i

R_FUNCT = {'add': 0x20, 'sub': 0x22, 'and': 0x24, 'or': 0x25, 'slt': 0x2a}
I_OP = {'lw': 0x23, 'sw': 0x2b, 'beq': 0x04}

RE_LABEL = re.compile(r'^([A-Za-z_]\w*)\s*:\s*(.*)$')
RE_MEMOP = re.compile(r'^(-?(?:0[xX][0-9a-fA-F]+|\d+))\s*\(\s*(\$\w+)\s*\)$')
RE_INT = re.compile(r'^-?(?:0[xX][0-9a-fA-F]+|\d+)$')


def die(msg, lineno=None):
    if lineno is not None:
        sys.exit('[asm] 第 %d 行: %s' % (lineno, msg))
    sys.exit('[asm] %s' % msg)


def strip_comment(raw):
    return raw.split('#', 1)[0].strip()


def parse_int(tok):
    tok = tok.strip()
    if not RE_INT.match(tok):
        die("看不懂的数字 '%s' (只支持 12 / -3 / 0x1f)" % tok)
    return int(tok, 0)


def reg_num(tok):
    t = tok.strip().lower()
    if t not in REG:
        die("未知寄存器 '%s'" % tok.strip())
    return REG[t]


def split_operands(ops):
    return [x.strip() for x in ops.split(',')] if ops.strip() else []


# ---------------------------------------------------------------- 主流程

def main():
    # Windows 控制台默认不是 UTF-8，打印中文会炸；Linux 上这行无副作用
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

    if len(sys.argv) != 2:
        sys.exit('用法: python3 test/asm.py <file.asm>')

    src = sys.argv[1]
    if not os.path.isfile(src):
        sys.exit('[asm] 找不到 %s' % src)

    with open(src, encoding='utf-8') as f:
        raw_lines = [(ln, r.rstrip('\n')) for ln, r in enumerate(f, 1)]

    # ---------------- 第一遍: 分配地址、收集标签 ----------------
    labels = {}
    text_items = []      # (行号, 助记符, 操作数串, 字节地址)
    data_words = []
    expects = []         # (0=寄存器/1=内存, 编号, 期望值)
    section = 'text'
    pc = 0

    for lineno, raw in raw_lines:
        line = strip_comment(raw)
        if not line:
            continue

        label, line = (None, line)
        m = RE_LABEL.match(line)
        if m:
            label = m.group(1)
            line = m.group(2).strip()
            if label in labels:
                die("标签 '%s' 重复定义" % label, lineno)
            labels[label] = pc if section == 'text' else len(data_words) * 4
        if not line:
            continue

        if line.startswith('.'):
            parts = line.split()
            d = parts[0].lower()

            if d == '.data':
                section = 'data'
            elif d == '.text':
                section = 'text'
            elif d == '.word':
                if section != 'data':
                    die('.word 必须写在 .data 段里', lineno)
                for tok in re.split(r'[,\s]+', ' '.join(parts[1:])):
                    if tok:
                        data_words.append(parse_int(tok) & 0xFFFF_FFFF)
            elif d == '.halt':
                if section != 'text':
                    die('.halt 必须写在 .text 段里', lineno)
                text_items.append((lineno, '.halt', '', pc))
                pc += 4
            elif d == '.expect':
                if len(parts) != 4:
                    die('.expect 格式: .expect reg $s0 12  或  .expect mem 3 8', lineno)
                kind = parts[1].lower()
                if kind == 'reg':
                    expects.append((0, reg_num(parts[2]), parse_int(parts[3]) & 0xFFFF_FFFF))
                elif kind == 'mem':
                    expects.append((1, parse_int(parts[2]), parse_int(parts[3]) & 0xFFFF_FFFF))
                else:
                    die(".expect 第一个参数只能是 reg 或 mem", lineno)
            else:
                die("未知伪指令 '%s'" % d, lineno)
            continue

        if section != 'text':
            die('指令必须写在 .text 段里', lineno)

        parts = line.split(None, 1)
        mn = parts[0].lower()
        ops = parts[1] if len(parts) > 1 else ''
        if mn not in R_FUNCT and mn not in I_OP:
            die("不支持的指令 '%s' (本工程只有 add sub and or slt lw sw beq)" % mn, lineno)
        text_items.append((lineno, mn, ops, pc))
        pc += 4

    if not text_items:
        die('没有找到任何指令，.text 段是空的')

    # ---------------- 第二遍: 编码 ----------------
    imem = []
    listing = []

    for lineno, mn, ops, addr in text_items:
        if mn == '.halt':
            word = (I_OP['beq'] << 26) | 0xFFFF          # beq $zero,$zero,-1
        elif mn in R_FUNCT:
            o = split_operands(ops)
            if len(o) != 3:
                die("%s 需要 3 个操作数: %s $rd, $rs, $rt" % (mn, mn), lineno)
            rd, rs, rt = reg_num(o[0]), reg_num(o[1]), reg_num(o[2])
            word = (rs << 21) | (rt << 16) | (rd << 11) | R_FUNCT[mn]
        elif mn in ('lw', 'sw'):
            o = split_operands(ops)
            if len(o) != 2:
                die("%s 需要 2 个操作数: %s $rt, imm($rs)" % (mn, mn), lineno)
            rt = reg_num(o[0])
            m = RE_MEMOP.match(o[1])
            if not m:
                die("地址要写成 imm($rs)，例如 0($zero) 或 -4($sp)", lineno)
            imm = parse_int(m.group(1))
            rs = reg_num(m.group(2))
            if not -32768 <= imm <= 65535:
                die('立即数超出 16 位范围', lineno)
            word = (I_OP[mn] << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
        else:                                            # beq
            o = split_operands(ops)
            if len(o) != 3:
                die("beq 需要 3 个操作数: beq $rs, $rt, label", lineno)
            rs, rt = reg_num(o[0]), reg_num(o[1])
            tgt = o[2]
            if tgt in labels:
                diff = labels[tgt] - (addr + 4)
                if diff % 4 != 0:
                    die("跳转目标 '%s' 没有按字对齐" % tgt, lineno)
                off = diff // 4
            elif RE_INT.match(tgt):
                off = parse_int(tgt)
            else:
                die("跳转目标 '%s' 既不是已定义的标签也不是数字" % tgt, lineno)
            if not -32768 <= off <= 32767:
                die('跳转偏移超出 16 位范围', lineno)
            word = (I_OP['beq'] << 26) | (rs << 21) | (rt << 16) | (off & 0xFFFF)
        imem.append(word & 0xFFFF_FFFF)

    # ---------------- 输出 ----------------
    base = os.path.splitext(src)[0]
    f_imem = base + '.imem.hex'
    f_dmem = base + '.dmem.hex'
    f_exp = base + '.expect'

    with open(f_imem, 'w', encoding='utf-8', newline='\n') as f:
        for w in imem:
            f.write('%08x\n' % w)

    with open(f_dmem, 'w', encoding='utf-8', newline='\n') as f:
        if data_words:
            for w in data_words:
                f.write('%08x\n' % w)
        else:
            f.write('%08x\n' % 0)          # 空文件会让 $readmemh 报警告，垫一个 0

    with open(f_exp, 'w', encoding='utf-8', newline='\n') as f:
        for kind, idx, val in expects:
            f.write('%d %d %08x\n' % (kind, idx, val))

    # 打印清单，方便肉眼核对机器码
    print('=== %s ===' % src)
    print('%-6s %-10s %s' % ('addr', 'code', 'source'))
    for (lineno, mn, ops, addr), word in zip(text_items, imem):
        print('0x%03x  %08x  %s %s' % (addr, word, mn, ops))

    if data_words:
        print('--- DMEM ---')
        for i, w in enumerate(data_words):
            print('DM[%d] = 0x%08x' % (i, w))

    if labels:
        print('--- 标签 ---')
        for k, v in labels.items():
            print('%-10s = 0x%03x (指令 %d)' % (k, v, v // 4))

    if expects:
        print('--- 期望终态 ---')
        for kind, idx, val in expects:
            print('%s[%d] = 0x%08x' % ('reg' if kind == 0 else 'DM', idx, val))

    print('写出: %s / %s / %s  (共 %d 条指令)'
          % (f_imem, f_dmem, f_exp, len(imem)))


if __name__ == '__main__':
    main()
