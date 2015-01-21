-------------------------------------------------- ----------------- 
               HID for PIC 18F14K50 bootloader / HIDmon 
   -------------------------------------------------- ----------------- 

■ Overview 

    This is based on HID boot loader for the PIC 18F4455 which diolan has to offer 
    This is the HID bootloader and HID monitor that you have created. 

■ What do you use? 

    MicroChip I can use to an alternate boot loader called Firmware-B that has to offer. 

    The boot loader: 

    18F2550 / 4550 / 14K50 series of PIC is, it is possible to PC and easily connect with USB, 
    By keep baked first boot loader, and use the PIC writer every time 
    Without having to transfer the program via USB, can be performed, easily programmed PIC 
    I can of development. 

    And not only that, we also combines the familiar features of HIDmon in AVR. 

■ hardware to prepare it? 

      PIC 18F14K50 (Akizuki It is sold on a per 200 yen by e-commerce) 
Or PIC18F2550 / 18F4550 


■ Can I use as a boot loader? 

    ● I can use once. 

    · The are prepared outside of PIC writer and burn the hexfiles / loader-18F14K50.hex. 
    • When connecting to the USB side, it is OK I start the connected LED flashes to RC0. 

     picmon / picmonit.exe: This is the PIC version of HIDmon. 
     picmon / picboot.exe: is the boot loader. I can write the HEX file. 
     But make sure that it works. 

    ● basic usage. 

    C:> picboot myfile.hex 
    I will write a myfile.hex into Flash. 

    C:> picboot -r 
    I will start the executable program from 0x800 address written into Flash. 

    C:> picboot -r myfile.hex 
    by writing myfile.hex in Flash, you run. (Do at a time two operations above) 

    C:> picboot -rp a.hex 
    I will output the contents of the Flash currently being written to 'a.hex' in HEXFILE format. 
 
    C:> picboot -E 
    I erased all the Flash content. (In normal writing, clear parts only need to write) 

    ● Option Description 

    · '-s' For options. 
        picboot -s1000 USBDevice-CDC-BasicDemo-C18-LowPinCountUSBDevelopmentKit.hex 
      If you specify a start address in hexadecimal following the '-s', not a start address 0x800 application 
    For I can write in bootable form. (Jmp table is written to address 0x800) 

    · '-B' For options. 
      '-B' Option is an option to allow read and write to the boot program area. 
By using this well, from the boot loader that was written to address 0x800, 0x0000 address of the boot loader 
You can perform the update. 

■ Notes on how to use the picboot 

    · If made to function as a boot loader by pressing the switch connected to terminal RC2 RC2 = Low Level 
      Please go energized, or reset from the state. 

    • If this is not the case looks like at address 0x800 application is started. 

    In the state (immediately after writing the first boot loader) the application has not been written 
      RC2 boot loader regardless of the terminal state is turned to start. 
      (At address 0x800, jump code back to the boot loader has been written) 



■ Please tell me how to use the test version (0x0800 origin). 

    • Use this boot loader, you have added a new version or a new feature loader 
      It is used when you want to develop. 



■ The process of re-build? 

    MicroChip of MPLab the (MPASMWIN) by installation, the execution path of MPASMWIN.EXE 
    Please keep in through. 

    - I run the make. general GNU make make.exe is being used in such WinAVR 
      I can use. 

    · Although it was also considered to use the gpasm of GNUPIC tool, fatal bug gpasm 
      Accordingly, since can not seem to generate the correct HID descriptor even if struggle 
      Recommended does not do. 
      (I will re-consider if it is modified gpasm bug) 
 

    ● the host side tool, please built using the MinGW gcc. 

       By attaching the -mno-cygwin option, it is possible to compile even Cywin gcc 
       You should, but are not tested. 


Changes from the original version bootloader ■ 

    · PIC18F14K50 I was supported. 
    · It is now can change the origin to be able to boot from the other boot loader. 
    -Encryption process I have removed on account of capacity. 
    · XINST I am that you do not use the (extended instruction that have been added in such PIC18F2550). 
       Specifically, it is addfsr and subfsr instruction. 


■ Notes 

    • This boot loader will work either XINST = ON / OFF, but the boot loader 
       Program to be started from the most that is assumed either by its writing 
       Is. 
    Especially, programs compiled with sdcc does not work not equal XINST = OFF. 
             ～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～～ ~~~~~~~~~~~~~~~ 
    · Please check well the mode of XINST if you bake. 
       If you want to change, please re-build by editing the XINST = item in fuse.h. 
    · Attached to have hexfiles it was created by XINST = OFF. 


■ Problems 

Because of the present condition source writing is full assembler flavor, maintainability compared with the C language 
There is a problem. 


■ Why do you not use the C language? 

Please listen-to diolan company. 

· Write a HID bootloader that will fit in 2kB in the C language and might have a daunting task. 
      HID bootloader of MicroChip is also 4kB. 

• You know immediately when I coded in C language to try. 

      code that would laugh and see the asm list has been vomit, but if anyone 
      You also can not. 
      All perhaps in front of the PIC18F architecture even if porting gcc is probably vain. 

      The only solution is to coding by hand all. Let's go back to the era of the TK-80. 


■ license? 

    · GPL It's (GNU Public License v3) is so. 


■ option of switching method 

(1) Makefile: 
     VECTOR = 0000 
     # VECTOR = 0800 
     # VECTOR = 1000 

     If Sashikaere the definition of the above VECTOR =, 0 address origin, the switching of the 800 address origin 
     Is possible. After rewriting, please make after you make clean. 

     VECTOR = If you chose the 0800 is made to the origin address 0x800, or other boot loader 
     You can be debugged using this boot loader. 



■ The difference between traditional hidmon-2550 / hidmon-14k50 it? 

· In the past, the host PC side of the tool (picmon.exe / picboot.exe) is separately for each device 
   I've been prepared to, and common respect tool on the PC in this version 
Are we. (However firmware will need to be prepared for each device) 

· I was changed to interrupt transfer from HID Report of transfer method the control transfer. 

We organize the command number to be given to the device. 
   pic18spx writer subset specification of I'm getting to (which was omitted writer system command). 
   Not done integration with pic18spx because ProductString is different at present. 

· BIOS function, poll system port access function you will find the omitted. 


# ------------------------------------------------- ------- 

■ change history 

  2010-0406: reboot modification of function.
