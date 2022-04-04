# PETTERM

**A bit-banged full duplex serial terminal for the Commodore PET/CBM computers,
including those running BASIC 1!**

Written by Hayden Kroepfl (Chartreuse) 2017-2020

BASIC Exit and Save/Load Options by Adam Whitney (K0FFY) 2022

## Latest Updates

PETTERM can now handle 2400 baud, along with much improved ANSI terminal compatibility.

Requires 8kB of RAM. (For 4kB PET's please use 0.4.0 version or prior for now.)

Support to Load and Save BASIC programs over the serial connection.

## Features

- Can work with a 40 or 80 column PETs with either the graphics or business keyboard.
- Can be loaded from tape or disk.
- Works on all versions of BASIC including the oldest PET 2001s with BASIC 1.
- Can work with as low as 8kB of RAM.
- Requires only a simple two wire serial interface.

## Usage

- Off/Rvs key acts as a Ctrl key.
- Clr/Home opens up the PETTERM menu for changing baud rate and character set modes
- PET cursor keys work as expected
- Inst/Del is a backspace key
- Additional shifted keys to improve *nix usability:
    - Shift-@ = ~
    - Shift-' = `
    - Shift-[ = {
    - Shift-] = }
    - Shift-^ (up arrow) = |
- Run/Stop sends Ctrl-C
- Other keys can be sent by their control code:
    - Tab = Ctrl-I
    - Esc = Ctrl-[ (For Alt/Meta, send Esc then the key)
- Terminal emulates ANSI escape codes (supports all required by ansi TERMCAP/TERMINFO)

## Hardware

**Rx** (to the PET) should be connected to pin C **AND** pin B of the user-port.

**Tx** (from the PET) should be connected to pin M of the user-port.

Don't forget the **ground** connection to either pin N or Pin 1

If coming from a version prior to 0.4.0, a connection between pin C and B of the user-port is required. Adapters meant for VIC-20 or C64 use should already have this present.
This change is required for all baud rates in this version.

**Warning:** Connections to the PET user port are RS-232 TTL level signals (0V to +5V). Standard RS-232 serial level signals are -13V to +13V (or more). Connecting standard RS-232 level signals to your PET's user port without an RS-232 to TTL interface will damage your computer and make you sad. (See this [SparkFun explanation](https://www.sparkfun.com/tutorials/215) for more details.)

## Files

- petterm40G - 40 column PETs with graphics keyboard (eg 2001, some 4032)
- petterm40B - 40 column PETs with buisness keyboard
- petterm80G - 80 column PETs with graphics keyboard
- petterm80B - 80 column PETs with buisness keyboard
- pettermb40G - 40 column PETs with graphics keyboard, BASIC save/load options
- pettermb40B - 40 column PETs with buisness keyboard, BASIC save/load options
- pettermb80G - 80 column PETs with graphics keyboard, BASIC save/load options
- pettermb80B - 80 column PETs with buisness keyboard, BASIC save/load options

PRG files are the native programs, can be added to a tape or disk image

TAP files are tape images
