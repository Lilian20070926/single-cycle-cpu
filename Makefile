# ============================================================
#  单周期 CPU —— 仿真流程
#  用法见 README.txt，或者直接 make help
# ============================================================

PYTHON ?= python3
PROG   ?= prog1

RTL := $(wildcard rtl/*.v)
TB  := tb/tb_cpu.v
SIM := build/sim
VCD := build/dump.vcd

.PHONY: all sim wave lint tb asm clean help

all: lint sim

# ------------------------------------------------------------------
# 单元测试：模块级 TB，写完一个模块就跑一次
#   alu         -> tb_alu.v
#   control+alucontrol -> tb_ctrl.v （两个一起测，因为接口是 ALUOp 编码）
#   regfile     -> tb_regfile.v
# 其它模块（signext/imem/dmem/pc）不值得单独写 TB，集成时一眼就看出来
# ------------------------------------------------------------------
tb:
	mkdir -p build
	iverilog -g2012 -Wall -o build/t_alu     rtl/alu.v tb/tb_alu.v
	iverilog -g2012 -Wall -o build/t_ctrl    rtl/control.v rtl/alucontrol.v tb/tb_ctrl.v
	iverilog -g2012 -Wall -o build/t_regfile rtl/regfile.v tb/tb_regfile.v
	vvp build/t_alu
	vvp build/t_ctrl
	vvp build/t_regfile

# 汇编测试程序，生成 test/$(PROG).imem.hex / .dmem.hex / .expect
asm:
	$(PYTHON) test/asm.py test/$(PROG).asm

# 汇编 + 仿真 + 自检
sim: $(SIM)
	$(PYTHON) test/asm.py test/$(PROG).asm
	vvp $(SIM) +IMEM=test/$(PROG).imem.hex +DMEM=test/$(PROG).dmem.hex +EXPECT=test/$(PROG).expect

# 编译。rtl 里只要有 .v 就全带上，加文件不用改这里
$(SIM): $(RTL) $(TB)
	mkdir -p build
	iverilog -g2012 -Wall -o $(SIM) $(RTL) $(TB)

# 跑完直接开波形
wave: sim
	gtkwave $(VCD) &

# verilator 静态检查，比 iverilog 严，专抓位宽不匹配和敏感表漏信号
lint:
	verilator --lint-only -Wall -Wno-fatal -Wno-DECLFILENAME --top-module cpu_top $(RTL)

clean:
	rm -rf build
	rm -f test/*.imem.hex test/*.dmem.hex test/*.expect

help:
	@echo "make tb              跑三个模块级单元测试（alu / ctrl / regfile）"
	@echo "make sim             汇编 + 仿真 + 自检（默认 PROG=prog1）"
	@echo "make sim PROG=t_rtype 只测 R 型五条"
	@echo "make sim PROG=t_mem   只测 lw / sw"
	@echo "make sim PROG=t_beq   只测 beq"
	@echo "make sim PROG=prog2   完整测试 + beq 循环"
	@echo "make wave            跑完直接开 gtkwave"
	@echo "make lint            verilator 静态检查（只查结构，不查功能）"
	@echo "make clean           清理 build 和生成的 hex"
