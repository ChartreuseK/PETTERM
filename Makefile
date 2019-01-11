
default:
	dasm petterm.s -f1 -obuild/petterm.prg -lbuild/petterm.lst
	
all:
	dasm petterm.s                   -f1 -obuild/petterm40G.prg -lbuild/petterm40G.lst
	dasm petterm.s -DCOL80           -f1 -obuild/petterm80G.prg -lbuild/petterm80G.lst
	dasm petterm.s -DBUISKBD         -f1 -obuild/petterm40B.prg -lbuild/petterm40B.lst
	dasm petterm.s -DBUISKBD -DCOL80 -f1 -obuild/petterm80B.prg -lbuild/petterm80B.lst
