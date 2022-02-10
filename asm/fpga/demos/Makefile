
XEX = \
	text_mode_attrib.xex
	
all: $(XEX)


%.xex: %.asm ../symbols.asm ../stdlib.asm ../graphics.asm
	mads $< -l -s -o:$@
	
clean:
	find ../asm -name "*.xex" -exec rm {} \;
	find ../asm -name "*.lst" -exec rm {} \;
	find ../asm -name "*.lab" -exec rm {} \;
	