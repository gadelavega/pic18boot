This version of Diolan's PIC bootloader has been derived from the code found in:
http://hp.vector.co.jp/authors/VA000177/html/pic18boot.html

It is actually not only a bootloader, but also a GP I/O device with HID interface. It also seems to be able to function as an AVR programmer.

The code as originally found does not work over high speed USB buses. The solution was suggested here:
http://www.microchip.com/forums/FindPost/841580

The patch was applied and solved the problem. Since the codo has been modified from the original Diolan's, the modification has to be made on a different line or it completely breaks the USB enumeration process.

Most of the documentation is or was in Japanese (use Japanese CP932 to open), a language which I can't read or speak, so I used online translation tool to start with and, as time allows, apply my best of the words and the programs to turn it into proper English.

I have also modified the code so it occupies 0x700 bytes (instead of 0x800, thats 1.75k instead of 2.0k). The build size is something less than 0x660 anyway. It will vary if configured in a different way. It may be possible to further reduce the size if I/O or AVR functions are not desired.

You may still find references to 0x800 size and reset vectors in comments and documentation.

The Makefile is configured to build under Linux with Microchip mpasmx

The original ReadMe.txt file is now called ReadMe.orig.txt
