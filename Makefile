DISK=galemu.dsk
ROMS=rom1.bin rom2.bin

.PHONY: clean

$(DISK): galemu.asm galfont.bin $(ROMS)
	pyz80.py --exportfile=galemu.sym galemu.asm

clean:
	rm -f $(DISK) galemu.sym
