# OVERVIEW

A test program for the BASIC Save/Load functionality of PETTERM.

# COMPILE

` cc -DDISPLAY_STRING petstream.c -o petstream`

# USAGE

` petstream SAVE`

This will wait for a BASIC program to be received over the serial port, and then save a pet_basic.seq file to disk.

` petstream LOAD`

This will send the pet_basic.seq file over the serial port.

# SAMPLE DATA

The pet_basic.seq file included here is one-line BASIC program comprised of the following 10 bytes:

0104 0b04 0a00 9922 4849 2200

This translates to the Commodore BASIC program:

10 PRINT"HI"

With the two header bytes of 01 (low byte) and 04 (high byte) specifying the PET/CBM Start of BASIC address of 0x0401.
