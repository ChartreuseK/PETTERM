SYS8K=2400
SYS16K=8192
SYS32K=20480
default:
	dasm petterm.s -DBASIC -f1 -obuild/petterm.prg -lbuild/petterm.lst
	
all:
	dasm petterm.s                   -f1 -obuild/petterm40G.prg -lbuild/petterm40G.lst
	dasm petterm.s -DCOL80           -f1 -obuild/petterm80G.prg -lbuild/petterm80G.lst
	dasm petterm.s -DBUISKBD         -f1 -obuild/petterm40B.prg -lbuild/petterm40B.lst
	dasm petterm.s -DBUISKBD -DCOL80 -f1 -obuild/petterm80B.prg -lbuild/petterm80B.lst

basic:
	$(info                                               )
	$(info **********************************************)
	$(info ************  8K HIMEM : SYS ${SYS8K} ************)
	$(info ***********  16K HIMEM : SYS ${SYS16K} ************)
	$(info ***********  32K HIMEM : SYS ${SYS32K} ***********)
	$(info **********************************************)
	$(info                                               )
	dasm petterm.s -DBASIC                   -f1 -obuild/petterm40G.prg -lbuild/petterm40G.lst
	dasm petterm.s -DBASIC -DCOL80           -f1 -obuild/petterm80G.prg -lbuild/petterm80G.lst
	dasm petterm.s -DBASIC -DBUISKBD         -f1 -obuild/petterm40B.prg -lbuild/petterm40B.lst
	dasm petterm.s -DBASIC -DBUISKBD -DCOL80 -f1 -obuild/petterm80B.prg -lbuild/petterm80B.lst
	dasm petterm.s -DBASIC -DHIMEM -DMEM8K                     -f1 -obuild/petterm8K_40G.prg -lbuild/petterm8K_40G.lst
	dasm petterm.s -DBASIC -DCOL80 -DHIMEM -DMEM8K             -f1 -obuild/petterm8K_80G.prg -lbuild/petterm8K_80G.lst
	dasm petterm.s -DBASIC -DBUISKBD -DHIMEM -DMEM8K           -f1 -obuild/petterm8K_40B.prg -lbuild/petterm8K_40B.lst
	dasm petterm.s -DBASIC -DBUISKBD -DCOL80 -DHIMEM -DMEM8K   -f1 -obuild/petterm8K_80B.prg -lbuild/petterm8K_80B.lst
	dasm petterm.s -DBASIC -DHIMEM -DMEM16K                    -f1 -obuild/petterm16K_40G.prg -lbuild/petterm16K_40G.lst
	dasm petterm.s -DBASIC -DCOL80 -DHIMEM -DMEM16K            -f1 -obuild/petterm16K_80G.prg -lbuild/petterm16K_80G.lst
	dasm petterm.s -DBASIC -DBUISKBD -DHIMEM -DMEM16K          -f1 -obuild/petterm16K_40B.prg -lbuild/petterm16K_40B.lst
	dasm petterm.s -DBASIC -DBUISKBD -DCOL80 -DHIMEM -DMEM16K  -f1 -obuild/petterm16K_80B.prg -lbuild/petterm16K_80B.lst
	dasm petterm.s -DBASIC -DHIMEM -DMEM32K                    -f1 -obuild/petterm32K_40G.prg -lbuild/petterm32K_40G.lst
	dasm petterm.s -DBASIC -DCOL80 -DHIMEM -DMEM32K            -f1 -obuild/petterm32K_80G.prg -lbuild/petterm32K_80G.lst
	dasm petterm.s -DBASIC -DBUISKBD -DHIMEM -DMEM32K          -f1 -obuild/petterm32K_40B.prg -lbuild/petterm32K_40B.lst
	dasm petterm.s -DBASIC -DBUISKBD -DCOL80 -DHIMEM -DMEM32K  -f1 -obuild/petterm32K_80B.prg -lbuild/petterm32K_80B.lst
