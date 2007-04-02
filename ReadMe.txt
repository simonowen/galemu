Galaksija Emulator v1.0
------------------

SAM version by Simon Owen
Based on Spectrum version by Tomaz Kac

Files:
 galemu.asm - Z80 source
 galfont.bin - character font
 rom1.bin - ROM (&0000-0fff)
 rom2.bin - ROM (&1000-1fff)

The Z80 source code uses the SAM Coupé Comet assembler syntax, as used by
Andrew Collier's pyz80.py cross-assembler.  Windows users will need to
have ActivePython or Cygwin Python installed to assemble it.

Building:
  pyz80.py galemu.asm

The output file is galemu.dsk, which is an auto-booting gzipped disk image
ready for use with SimCoupe.

Links:
  pyz80 - http://www.intensity.org.uk/samcoupe/pyz80.html
  ActivePython - http://www.activestate.com/products/activepython/
  SimCoupe - http://www.simcoupe.org/
  Tomaz Kac's Homepage: http://retrospec.sgn.net/users/tomcat/

---
Simon Owen
http://simonowen.com/
