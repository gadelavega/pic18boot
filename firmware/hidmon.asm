; Tabsize: 4
;-----------------------------------------------------------------------------
;	H I D m o n  : main process
;-----------------------------------------------------------------------------
	#include "p18fxxxx.inc"
	#include "usb.inc"
	#include "boot.inc"
	#include "boot_if.inc"
	#include "usb_defs.inc"
	#include "hidcmd.inc"
	#include "io_cfg.inc"
;-----------------------------------------------------------------------------
; API:
;	hid_process_cmd		// HID_Report Analyzes, to create the reply packet .
;	cmd_echo			// echo back.
;	cmd_peek			// memory read.
;	cmd_poke			// memory write.
;-----------------------------------------------------------------------------
; major work:
;	boot_cmd[64];		// HID_Report packets attached fed from the host.
;	boot_rep[64];		// HID_Report packets to be sent back to the host.
;-----------------------------------------------------------------------------

;//	Version 1.1
#define	DEV_VERSION_H	1
#define	DEV_VERSION_L	1
#define	DEV_BOOTLOADER	1
;-----------------------------------------------------------------------------
;	Externals.
;-----------------------------------------------------------------------------
	extern	cmd_page_tx		; Flash writing.
	extern	cmd_page_erase		; Flash erase.
	extern	usb_state_machine

; write eeprom EEADR,EEDATA must be preset, EEPGD must be cleared       
	extern	eeprom_write

;-----------------------------------------------------------------------------
;	External variables ( buffer ).
;-----------------------------------------------------------------------------
	extern	ep1Bo
	extern	ep1Bi
;;	extern	boot_cmd		; cmd receiving buffer.
;;	extern	boot_rep		; rep transmission buffer.

	extern	SetupPktCopy
	extern	usb_init

#if USE_SRAM_MARK
	extern	usb_initialized
#endif

;-----------------------------------------------------------------------------
;	Global variables.
;-----------------------------------------------------------------------------
	
	global	cmdsize;
;-----------------------------------------------------------------------------
;	Local variables.
;-----------------------------------------------------------------------------
BOOT_DATA	UDATA

cmdsize		res	1	; Read size.
area		res	1	; Reading area.
ToPcRdy		res	1	; If you return the command execution result in PC 1.

poll_mode	res	1	; Reading mode to be executed when POLL command accepted (0=digital 0xAx=analog)
poll_addr_l	res	1	; Memory read address to be executed when POLL command accepted
poll_addr_h	res	1	; Memory read address to be executed when POLL

;pollstat	res	1	; POLL command wait = 1 POLL Executed = 0
;str_chr		res	1	; Temporary work for character output
;key_chr		res	1	; For character input buffer ( one character only) without input when the 0
;hid_chr		res	1	; When you receive the HID block 1.
;snapcnt		res 1

#if	0
		global	BiosPutcBuf
		global	BiosGetsBuf

;	Used for Putc/Getc
BiosPutcBuf	res	8	;;64
BiosGetsBuf	res	8	;;64
#endif

		global	boot_cmd
		global	boot_rep
;-----------------------------------------------------------------------------
HID_BUF	UDATA	DPRAM+0x70

boot_cmd	res		64	;;EP0_BUFF_SIZE
boot_rep	res		64	;;BOOT_REP_SIZE	; CtrlTrfData and I want to share.

;--------------------------------------------------------------------------
;//	Memory type.
#define	AREA_RAM     0
#define	AREA_EEPROM  0x40
#define	AREA_PGMEM   0x80
#define	AREA_MASK    0xc0
#define	SIZE_MASK    0x3f


; Breakdown of boot_cmd [64].
#define	size_area	boot_cmd+1	;size(0..63)|area(bit7,6)
#define	addr_l		boot_cmd+2
#define	addr_h		boot_cmd+3
#define	data_0		boot_cmd+4	;Write data.
#define	data_1		boot_cmd+5	;Write mask.



#define	UOWNbit		7

#define	REPLY_REPORT	0xaa


;#define mHIDRxIsBusy()              HID_BD_OUT.Stat.UOWN
;#define mHIDTxIsBusy()              HID_BD_IN.Stat.UOWN



BOOT_ASM_CODE	CODE

;-----------------------------------------------------------------------------
;	
;-----------------------------------------------------------------------------
	global	bios_task
bios_task
	movlb	GPR0
	;;; App to start alone, when bios_task is called during the first round,
	;;; it is necessary to perform initialization of usb.
#if USE_SRAM_MARK
	if_ne	usb_initialized  ,0x55,		bra,re_init
	if_ne	usb_initialized+1,0xaa,		bra,re_init
	bra	hid_process_cmd
#endif

	;; If it detects a USB uninitialized, reinitialize
re_init
	rcall	usb_init
	;;; «««
;-----------------------------------------------------------------------------
;	processing code for HID packet.
;-----------------------------------------------------------------------------

	global	hid_process_cmd
hid_process_cmd
	movlb	GPR0

	rcall	usb_state_machine

;	TRANSLATION: No Idea what the following woud mean!
;	TODO: there is a problem with too fast hosts: it could lie somewhere around here.
;	// It reply packet is empty, and,
;	// A receive data to be processed.
;	if((!mHIDRxIsBusy())) {

	btfsc	ep1Bi ,UOWNbit	; SIE During SIE operation? (In reply)
	bra	hid_proc_end	; Do not process command because it is running.
	btfsc	ep1Bo ,UOWNbit	; SIE ( in the command reception)
	bra	hid_proc_poll	; Command is not received.


; Command processing
;	{
	rcall	switch_case_cmd
;;;		rcall	led0_flip
;;;		rcall	snapshot

		;; Kick the following reception.
;		lfsr	FSR0 , ep1Bo
;		rcall	mUSBBufferReady
;	}
hid_proc_1
;	// If necessary , to return to the host PC the reply
;	// packet interrupt transfer (EP1).
;	if( ToPcRdy ) {
;		if(!mHIDTxIsBusy()) {
;			HIDTxReport64((char *)&PacketToPC);
;			ToPcRdy = 0;
;
;			if(poll_mode!=0) {
;				if(mHIDRxIsBusy()) {	//Continue to send as long as the command does not come.
;					make_report();
;				}
;			}
;		}
;	}
;	rcall	led0_flip

	if_eq	ToPcRdy	, 0 , 	bra,hid_proc_2	; Do not USB reply if ToPcRdy == 0.
	btfsc	ep1Bi ,UOWNbit	; During SIE operation ? ( In reply )
	bra	hid_proc_3	; Do not respond because during operation.
		
	clrf	ToPcRdy
		;; And kick a reply.
	lfsr	FSR0 , ep1Bi
	rcall	mUSBBufferReady
;;		bra		hid_proc_3
;TODO: shouldn't we jump to the end from here? rcall mUSBBufferReady will return here
; Otherwise use goto, not rcall
hid_proc_2

hid_proc_3

	;; Kick the following reception.
	lfsr	FSR0 , ep1Bo
;;	rcall	mUSBBufferReady
;;	return

;#define mUSBBufferReady(buffer_dsc)                                         \
;{                                                                           \
;    buffer_dsc.Stat._byte &= _DTSMASK;          /* Save only DTS bit */     \
;    buffer_dsc.Stat.DTS = !buffer_dsc.Stat.DTS; /* Toggle DTS bit    */     \
;    buffer_dsc.Stat._byte |= _USIE|_DTSEN;      /* Turn ownership to SIE */ \
;}
mUSBBufferReady
	movlw	64
	st	PREINC0
	ld	POSTDEC0
	
	ld	INDF0
	xorlw	_DTSMASK
	andlw	_DTSMASK
	st	INDF0
	iorlw	_USIE|_DTSEN
	st	INDF0
hid_proc_end
	return


;-----------------------------------------
hid_proc_poll
;;	btfsc	ep1Bi ,UOWNbit	; During SIE operation ? ( In reply )
;;	bra	hid_proc_end	; It does not command processing because it is running .

	if_eq	poll_mode,0		,bra,hid_proc_poll_end

	rcall	make_report
		;;And kick a reply.
	lfsr	FSR0 , ep1Bi
	rcall	mUSBBufferReady

hid_proc_poll_end
	return

#if	0	;// debug only
led0_flip
	btfsc	LED,LED_PIN0
	bra	led0_off
led0_on
	bsf	LED, LED_PIN0	;; debug
	return
led0_off
	bcf	LED, LED_PIN0	;; debug
	return

snapshot
	lfsr	FSR2,0x400
	lfsr	FSR0,0
	movlw	0
	rcall	cmd_peek_ram_l	;; fsr2->fsr0

	incf	snapcnt
	movff	snapcnt,0x6f
	return
#endif

;-----------------------------------------------------------------------------
;	Processing code for hidmon command.
;-----------------------------------------------------------------------------
switch_case_cmd
	;;Copy the first byte of the to boot_rep [].
	ld	boot_cmd
	st	boot_rep

	andlw	1
	st	ToPcRdy

	ld	boot_cmd
	dcfsnz	WREG	; HIDASP_TEST         1 ;//Echo back (R)
	bra	cmd_echo
	dcfsnz	WREG	; HIDASP_BOOT_EXIT    2 ;//Exit the bootload, to start the application.
	bra	cmd_reset
	decf	WREG	; reserved            3
	dcfsnz	WREG	; HIDASP_POKE         4	;//Memory write.
	bra	cmd_poke
	dcfsnz	WREG	; HIDASP_PEEK         5	;//Memory read . (R)
	bra	cmd_peek
	dcfsnz	WREG	; HIDASP_JMP	      6	;//Program execution of the specified address.
	bra	cmd_jmp
	dcfsnz	WREG	; HIDASP_SET_MODE     7	;//poll mode setting of (R)
	bra	cmd_set_mode
	dcfsnz	WREG	; HIDASP_PAGE_ERASE	  8 ;//Flash erase.
	bra	cmd_page_erase
	dcfsnz	WREG	; HIDASP_KEYINPUT	  9 ;//Send the host side of the keyboard.
	bra	unknown_cmd;cmd_keyinput
	dcfsnz	WREG    ; HIDASP_PAGE_WRITE   10;//
	bra	cmd_page_tx
;;-----------------------------------------------------------------------------
;;	Response to an unknown packet.
;;-----------------------------------------------------------------------------
unknown_cmd
return_hid_process_cmd
	return



;-----------------------------------------------------------------------------
;	boot_rep [64] of the return buffer setup.
;-----------------------------------------------------------------------------

#ifdef __18F14K50
#define	DEVICE_ID	DEV_ID_PIC18F14K
#else
#define	DEVICE_ID	DEV_ID_PIC
#endif

;-----------------------------------------------------------------------------
;	buf[0] = HIDASP_ECHO;
;	buf[1] = ECHO BACK DATA;
cmd_echo
	lfsr	FSR0 , boot_rep+1
;;	movff	boot_cmd 	, POSTINC0	; [0] = CMD_ECHO
	movlf	DEVICE_ID	, POSTINC0	; [1] = DEV_ID
	movlf	DEV_VERSION_L	, POSTINC0	; [2] = HIDmon Device Version lo
	movlf	DEV_VERSION_H	, POSTINC0	; [3] = HIDmon Device Version hi
	movlf	DEV_BOOTLOADER	, POSTINC0	; [4] = AVAILABLE BOOTLOADER FUNC
	movff	boot_cmd+1   	, POSTINC0	; [5] = ECHO BACK DATA
	return



;-----------------------------------------------------------------------------
;	Set the variable cmdsize and area.
;	buf[1] = HIDASP_PEEK;
;	buf[2] = size | area;
;
	global	get_size_arena
get_size_arena
	ld	size_area
	andlw	SIZE_MASK
	
	bnz	get_size_a1
	movlw	SIZE_MASK + 1	; size == 0 I be interpreted as 64.
get_size_a1
	st	cmdsize

	ld	size_area
	andlw	AREA_MASK
	st	area
	return

;-----------------------------------------------------------------------------
;	buf[0] = HIDASP_PEEK;
;	buf[1] = size | area;
;	buf[2] = addr;
;	buf[3] =(addr>>8);
cmd_peek
	;; Transfer destination boot_rep
	lfsr	FSR0 , boot_rep
	
	rcall	get_size_arena
	bz	cmd_peek_ram
	if_eq	area,AREA_EEPROM	,bra ,cmd_peek_eeprom
;-----------------------------------------------------------------------------
;	ROM read.
;-----------------------------------------------------------------------------
cmd_peek_rom
	;; And set the read source (ROM) address.
	clrf	TBLPTRU
	movff	addr_h, TBLPTRH
	movff	addr_l, TBLPTRL

	;; And set the read destination = Transmit buffer.
	;lfsr	FSR0 , boot_rep
	;; And set the ReportID.
	;;movlf	REPORT_ID1 , POSTINC0

	;; And set the transfer length to WREG.
	movf	cmdsize , W
cmd_peek_rom_l
	tblrd*+				;; read from the ROM.
	movff	TABLAT , POSTINC0	;; Transfer the latch of the ROM in the transmit buffer.
	decfsz	WREG
	bra	cmd_peek_rom_l		;; Repeat only transfer length worth.
cmd_peek_rom_q
	return
;-----------------------------------------------------------------------------
;	RAM read.
;-----------------------------------------------------------------------------
cmd_peek_ram
	movff	addr_h, FSR2H
	movff	addr_l, FSR2L

	;; Set the transfer length to WREG.
	movf	cmdsize , W

memcpy_fsr2to0

cmd_peek_ram_l
	movff	POSTINC2 , POSTINC0	;; Transfer the area of RAM to the transmit buffer.
	decfsz	WREG
	bra		cmd_peek_ram_l	;; repeat only transfer length worth.
cmd_peek_ram_q
	return

;-----------------------------------------------------------------------------
;	RAM read.
;-----------------------------------------------------------------------------
cmd_peek_eeprom
	ld	addr_l		; EEPROM address
	st	EEADR
	clrf	EECON1, W

	;; set the transfer length to WREG.
	;ld	cmdsize		--> WREG directly dec is not used.
cmd_peek_eeprom_l
	bsf	EECON1, RD			; Read data
	ld	EEDATA
	st	POSTINC0
	incf	EEADR, F			; Next address
	decfsz	cmdsize			;WREG
	bra	cmd_peek_eeprom_l
	return
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
;	buf[0] = HIDASP_POKE;
;	buf[1] = size | area;
;	buf[2] = addr;
;	buf[3] =(addr>>8);
;	buf[4] = data_0;
;	buf[5] = data_1;
cmd_poke
	rcall	get_size_arena
	bz		cmd_poke_ram
;;	if_eq	area,AREA_EEPROM	,bra ,cmd_poke_eeprom
;-----------------------------------------------------------------------------
;	EEPROM write.
;-----------------------------------------------------------------------------
cmd_poke_eeprom
	ld		addr_l		; EEPROM address
	st		EEADR
	clrf	EECON1, W

;;write_eeprom_loop
	ld	data_0
	st	EEDATA
	bcf	EECON1, EEPGD	; Access EEPROM (not code memory)
	rcall	eeprom_write
	btfsc	EECON1, WR	; Is WRITE completed?
	bra	$ - 2		; Wait until WRITE complete
;	incf	EEADR, F	; Next address
;;	decfsz	cntr
;;	bra	write_eeprom_loop
	bcf	EECON1, WREN	; Disable writes
	return

;	implementation in flash.asm.
;eeprom_write
;	bcf	EECON1, CFGS	; Access code memory (not Config)
;	bsf	EECON1, WREN	; Enable write
;	movlf	0x55,EECON2
;	movlf	0xAA,EECON2
;	bsf	EECON1, WR	; Start flash/eeprom writing
;	clrf	hold_r		; hold_r=0
;	return

;-----------------------------------------------------------------------------
;	RAM write.
;-----------------------------------------------------------------------------
;	uchar data=cmd->memdata[0];
;	uchar mask=cmd->memdata[1];
;	if(mask) {	//Writing with a mask.
;		*p = (*p & mask) | data;
;	}else{			//Solid writing. TRANSLATION: solid == hard?
;		*p = data;
;	}

cmd_poke_ram
	movff	addr_h, FSR0H
	movff	addr_l, FSR0L
	ld	data_1
	bz	direct_write_ram
; MASK writing.
	andwf	INDF0 , W
	iorwf	data_0, W
	st	data_0
direct_write_ram
	movff	data_0 , POSTINC0	;; Rewrites the area of RAM.
	return


#if	0
;-----------------------------------------------------------------------------
;	USB: it is called from HID_Report IN.
;-----------------------------------------------------------------------------
	global	cmd_poll
cmd_poll
;;	movlw	REPORT_ID2		; HID ReportID = 4 (poll)
	cpfseq	(SetupPktCopy + wValue)	; request HID_ReportID
	return
	;; if( wValue == REPORT_ID2 ) {
		movlw	0
		cpfseq	poll_mode
		;; if ( pagemode != 0 ) goto cmd_poll_string
		bra		cmd_poll_string

		;; else {
			movff	pageaddr_l,FSR0L
			movff	pageaddr_h,FSR0H
			ld	INDF0 			; Port Reading.
;;;			st	boot_rep + 1		; write to return buffer [1 ].
			movff	WREG,boot_rep + 1	; write to return buffer [1 ].
;;			movlf	REPORT_ID2,boot_rep	; write to HID ReportID = 2 (poll) the return buffer [0 ].
		;; }
	;; }

	return
#endif

#if	0
;-----------------------------------------------------------------------------
;	USB: receive the HID data (63byte) any from the host PC.
;-----------------------------------------------------------------------------
;cmd_gethid
;--- EP0 direct copy.
;	lfsr	FSR0,BiosGetsBuf
;	lfsr	FSR2,boot_rep
;	movlw	64
;	rcall	memcpy_fsr2to0	; memcpy(boot_rep,BiosPutcBuf,62);
;	movlf	1,hid_chr
;	return
;-----------------------------------------------------------------------------
;	USB: it is called from HID_Report IN.
;	send the printf string to the host PC.
;-----------------------------------------------------------------------------
;	Storage location of string data:
;		BiosPutcBuf[2]     = Number of characters.
;		BiosPutcBuf[3`63] = String.
;	The following is a fixed value:
;		BiosPutcBuf[0]     = REPORT_ID2.
;		BiosPutcBuf[1]     = Mark indicating that 0xc0 return information is a string.
;
cmd_poll_string
	lfsr	FSR2,BiosPutcBuf
;;	movlf	REPORT_ID2,POSTINC2	; Write HID ReportID = 2 the (poll) to BiosPutcBuf [0].
	movff	pagemode,  POSTINC2	; Write String Mark to BiosPutcBuf [1].
;--- Directly copied to the EP0 in.
	lfsr	FSR2,BiosPutcBuf
	lfsr	FSR0,boot_rep
	movlw	62
	rcall	memcpy_fsr2to0		; memcpy(boot_rep,BiosPutcBuf,62);
	clrf	pollstat
;--- Reset the number of characters.
	lfsr	FSR0,BiosPutcBuf+2
	clrf	INDF0
	return
#endif

#if	0
;-----------------------------------------------------------------------------
;	API:.. 1 character key input and returns a 0 if there is no input result => WREG
;-----------------------------------------------------------------------------
	global	bios_getc
bios_getc
	movlb	GPR0
	ld	key_chr
	clrf	key_chr
	return
;-----------------------------------------------------------------------------
;	API: I store one character output (WREG) ===> BiosPutcBuf.
;-----------------------------------------------------------------------------
;	Once full, waiting for the completion of USB communication , also accumulate.
	global	bios_putc
bios_putc
	movlb	GPR0

	st	str_chr
	lfsr	FSR0,BiosPutcBuf+2	;; Number of characters.
	if_ge	INDF0 , 59,		rcall, bios_putc_flush	;;Already 60 characters registered.

	ld	INDF0			;; WREG = number of characters
	addlw	LOW(BiosPutcBuf+3);	;; The beginning of the string buffer.
	st	FSR0L			;; Current position of the string buffer.
	
	movff	str_chr , INDF0		;; Stores argument of character to BiosPutcBuf [3 + cnt].

	lfsr	FSR0,BiosPutcBuf+2	;; Number of characters.
	incf	INDF0			;; The number of characters cnt +1.

	return
;-----------------------------------------------------------------------------
;		Once full, waiting for the completion of USB communication , also accumulate.
;-----------------------------------------------------------------------------
bios_putc_flush
	rcall	bios_task
	lfsr	FSR0,BiosPutcBuf+2	;; Number of characters.
	if_ge	INDF0 , 59,		bra, bios_putc_flush	;;Already 60 characters registered.

	return

#endif

;-----------------------------------------------------------------------------
;	API: set of string transfer mode by HID Report.
;-----------------------------------------------------------------------------
;	pagemode = 0    : Ordinary usb_poll ( use the Graph command )
;	pagemode = 0xAx : Analog input support command in HIDmon-2313.
;	pagemode = 0xc0 : Normal string transfer . ( The take-off mode to the host PC)
;	pagemode = 0xc9 : Application termination notice ( host PC comes out of Terminal loop )
;
;;	global	bios_setmode
;bios_setmode
;	movlb	GPR0
;	st	poll_mode
;
;	return
;-----------------------------------------------------------------------------
;	Run.
;-----------------------------------------------------------------------------
;	uchar bootflag=PacketFromPC.raw[5];
;	if(	bootflag ) {
;		wait_ms(10);
;		usbModuleDisable();		// Once I disconnect the USB.
;		wait_ms(10);
;	}
cmd_jmp
;;	if_eq	data_1,0	,bra,cmd_jmp_1

	;; USB disconnect
	dcfsnz	data_1		; The data_1 to disconnect the == 1 if USB.
	rcall	usb_disconnect	; Disable USB Engine


cmd_jmp_1
	clrf	PCLATU
	ld	addr_h
	st	PCLATH
	ld	addr_l

	movlb	0
	st	PCL
	return			;; Maybe unnecessary.

;-----------------------------------------------------------------------------
;	Reset.
;-----------------------------------------------------------------------------
cmd_reset
	rcall	usb_disconnect	 ; Disable USB Engine

#if USE_SRAM_MARK
	movlf	0x55,usb_initialized
	movlf	0x5e,usb_initialized+1
#endif

	reset

;-----------------------------------------------------------------------------

usb_disconnect
	rcall	delay_loop
	bcf     UCON,USBEN      ; Disable USB Engine

delay_loop
	; Delay to show USB device reset
	clrf	cmdsize
cmd_reset_1
	clrf	WREG
cmd_reset_2
	decfsz	WREG
	bra	cmd_reset_2
	decfsz	cmdsize
	bra	cmd_reset_1
	return

;-----------------------------------------------------------------------------
;	buf[0] = HIDASP_SET_MODE;
;	buf[1] = mode (digital=0, analog=0xAx) ;
;	buf[2] = addr;
;	buf[3] =(addr>>8);
;	CMD_POLL In advance set the port and mode to read in.
cmd_set_mode
	movff	size_area,poll_mode		; handle the size value as read mode.
	movff	addr_l	 ,poll_addr_l
	movff	addr_h	 ,poll_addr_h

make_report
;	//Return the sample values.
	movlf	REPLY_REPORT , boot_rep		;// inform the command execution completion to HOST.
	;;		PacketToPC.raw[1] = 1;
	movlf	1			 , boot_rep+1	;//Number of samples.
	;;		PacketToPC.raw[2] = *poll_addr;
	;; {
		movff	poll_addr_l,FSR0L
		movff	poll_addr_h,FSR0H
		ld		INDF0 			; Port Reading.
		st		boot_rep + 2		; write to return buffer [2 ].
	;; }
;	movlf	1,ToPcRdy
;;	return

;-----------------------------------------------------------------------------
;	buf[1] = HIDASP_KEYINPUT;
;	buf[2] = KEY Charactr
;	Key input is sent from the host.
;;cmd_keyinput
;;	movff	size_area,key_chr		; handle the size value as Character.
;;	return
;-----------------------------------------------------------------------------
;
;-----------------------------------------------------------------------------

	END
