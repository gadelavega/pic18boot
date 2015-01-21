; Tabsize: 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  BootLoader.                                                             ;;
;;  Copyright (C) 2007 Diolan ( http://www.diolan.com )                     ;;
;;                                                                          ;;
;;  This program is free software: you can redistribute it and/or modify    ;;
;;  it under the terms of the GNU General Public License as published by    ;;
;;  the Free Software Foundation, either version 3 of the License, or       ;;
;;  (at your option) any later version.                                     ;;
;;                                                                          ;;
;;  This program is distributed in the hope that it will be useful,         ;;
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of          ;;
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           ;;
;;  GNU General Public License for more details.                            ;;
;;                                                                          ;;
;;  You should have received a copy of the GNU General Public License       ;;
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; USB Descriptors
;-----------------------------------------------------------------------------
	#include "p18fxxxx.inc"
	#include "boot.inc"
	#include "usb_defs.inc"
	#include "usb_desc.inc"


;-----------------------------------------------------------------------------
; Packed code segment for USB descriptor
; We need to avoid zero padding for descriptors.
; And put descriptors after XTEA_KEY_SECTION.
USB_DESCRIPTORS	CODE_PACK	VECT + 0x01C
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; USB Device Descriptor
USB_DEV_DESC
USB_DEV_DESC_bLength		db	(USB_DEV_DESC_end - USB_DEV_DESC)	; Size
USB_DEV_DESC_bDscType		db	DSC_DEV	; Descriptor type = device
USB_DEV_DESC_bcdUSB			dw	0x0200	; 0x0200	; USB 2.0 version
USB_DEV_DESC_bDevCls		db	0x00	; HID=00: Class. Specified at Interface level
USB_DEV_DESC_bDevSubCls		db	0x00	; SubClass. Specified at Interface level
USB_DEV_DESC_bDevProtocol	db	0x00	; Protocol. Specified at Interface level
USB_DEV_DESC_bMaxPktSize0	db	EP0_BUFF_SIZE
USB_DEV_DESC_idVendor		dw	0x04d8	;BOOTLOADER_VID
USB_DEV_DESC_idProduct		dw	0x003c	;BOOTLOADER_PID
USB_DEV_DESC_bcdDevice		dw	0x0002	;FW_VER_CODE ; Device release number
USB_DEV_DESC_iMfg			db	0x01 	; Manufacturer string index
USB_DEV_DESC_iProduct		db	0x02 	; Product string index
USB_DEV_DESC_iSerialNum		db	0x03	; No serial number
USB_DEV_DESC_bNumCfg		db	0x01	; One configuration supported
USB_DEV_DESC_end


;-----------------------------------------------------------------------------
; Configuration Descriptor
; This descriptor includes Interface and endpoints' descriptors inplace
; Configuration 1 Descriptor
USB_CFG_DESC
USB_CFG_DESC_bLength		db	(USB_CFG_DESC_end - USB_CFG_DESC) ; Size
USB_CFG_DESC_bDscType		db	DSC_CFG		; Descriptor type = Configuration
USB_CFG_DESC_wTotalLength	dw	(USB_CFG_DESC_Total_end - USB_CFG_DESC) ; Total length of data for this configuration
USB_CFG_DESC_bNumIntf		db	1		; Number of interfaces
USB_CFG_DESC_bCfgValue		db	1		; Index value of this configuration
USB_CFG_DESC_iCfg			db	0		; Configuration string index
USB_CFG_DESC_bmAttributes	db	CFG_ATTRIBUTES	; Attributes
USB_CFG_DESC_bMaxPower		db	.50		; Max power consumption (2X mA)
USB_CFG_DESC_end
; Interface Descriptor included in configuration
USB_IF_DESC
USB_IF_DESC_bLength			db	(USB_IF_DESC_end - USB_IF_DESC)	; Size
USB_IF_DESC_bDscType		db	DSC_INTF	; Descriptor type = Interface
USB_IF_DESC_bIntfNum		db	0		; Interface Number
USB_IF_DESC_bAltSetting		db	0		; Alternate Setting Number
USB_IF_DESC_bNumEPs			db	HAVE_ENDPOINT	; Number of endpoints
USB_IF_DESC_bIntfCls		db	HID_INTF	; HID_INTF=3	; HID Interface Class Code
USB_IF_DESC_bIntfSubCls		db	NO_SUBCLASS	; HID Interface Class SubClass Codes
USB_IF_DESC_bIntfProtocol	db	HID_PROTOCOL_NONE	; HID Interface Class Protocol Codes
USB_IF_DESC_iIntf			db	0		; Interface string index
USB_IF_DESC_end
; HID Class-Specific Descriptor included in configuration
USB_HID_DESC
USB_HID_DESC_bLength		db	(USB_HID_DESC_end - USB_HID_DESC)	; Size
USB_HID_DESC_bDscType		db	DSC_HID	; HID descriptor type
USB_HID_DESC_bcdHID			dw	0x0101	; HID Spec Release Number in BCD format
USB_HID_DESC_bCountryCode	db	0x00	; Country Code (0x00 for Not supported)
USB_HID_DESC_bNumDsc		db	HID_NUM_OF_DSC	; Number of class descriptors
USB_HID_DESC_HDR_bDscType	db	DSC_RPT	; Report descriptor type
USB_HID_DESC_wDscLength		dw	(USB_HID_RPT_end - USB_HID_RPT)	; Size of the report descriptor
USB_HID_DESC_end

#if	HAVE_ENDPOINT
; Endpoint Descriptors included in configuration
USB_EPi_DESC
USB_EPi_DESC_bLength		db	(USB_EPi_DESC_end - USB_EPi_DESC)	; Size
USB_EPi_DESC_bDscType		db	DSC_EP			; Descriptor type = Endpoint
USB_EPi_DESC_bEPAdr			db	_EP01_IN		; Endpoint Address
USB_EPi_DESC_bmAttributes	db	_INT			; Endpoint type
USB_EPi_DESC_wMaxPktSize	dw	HID_IN_EP_SIZE		; Endpoint size
USB_EPi_DESC_bInterval		db	0x01			; Pool interval
USB_EPi_DESC_end

USB_EPo_DESC
USB_EPo_DESC_bLength		db	(USB_EPo_DESC_end - USB_EPo_DESC)	; Size
USB_EPo_DESC_bDscType		db	DSC_EP			; Descriptor type = Endpoint
USB_EPo_DESC_bEPAdr			db	_EP01_OUT		; Endpoint Address
USB_EPo_DESC_bmAttributes	db	_INT			; Endpoint type
USB_EPo_DESC_wMaxPktSize	dw	HID_OUT_EP_SIZE		; Endpoint size
USB_EPo_DESC_bInterval		db	0x01			; Pool interval
USB_EPo_DESC_end
#endif

USB_CFG_DESC_Total_end
;-----------------------------------------------------------------------------
; Report descriptor
#if	HAVE_ENDPOINT

USB_HID_RPT
;;PROGMEM char usbHidReportDescriptor[] = {
    db 0x06, 0x00, 0xff             ;// USAGE_PAGE (Generic Desktop)
    db 0x09, 0x01                   ;// USAGE (Vendor Usage 1)
    db 0xa1, 0x01                   ;// COLLECTION (Application)
    db 0x19, 0x01                   ;//   Usage Minimum 
    db 0x29, 0x40                   ;//   Usage Maximum,input usages total (0x01 to 0x40)
    db 0x15, 0x00                   ;//   LOGICAL_MINIMUM (0)
    db 0x26, 0xff, 0x00             ;//   LOGICAL_MAXIMUM (255)
    db 0x75, 0x08                   ;//   REPORT_SIZE (8)
    db 0x95, 0x40                   ;//   REPORT_COUNT (64)
    db 0x81, 0x00                   ;//   Input (Data, Array, Abs): 
    db 0x19, 0x01                   ;//   Usage Minimum 
    db 0x29, 0x40                   ;//   Usage Maximum,input usages total (0x01 to 0x40)
    db 0x91, 0x00                   ;//   Output (Data, Array, Abs):
    db 0xc0                         ;// END_COLLECTION
;; };
USB_HID_RPT_end

#else

USB_HID_RPT
;;PROGMEM char usbHidReportDescriptor[] = {
    db 0x06, 0x00, 0xff             ;// USAGE_PAGE (Generic Desktop)
    db 0x09, 0x01                   ;// USAGE (Vendor Usage 1)
    db 0xa1, 0x01                   ;// COLLECTION (Application)
    db 0x15, 0x00                   ;//   LOGICAL_MINIMUM (0)
    db 0x26, 0xff, 0x00             ;//   LOGICAL_MAXIMUM (255)
    db 0x75, 0x08                   ;//   REPORT_SIZE (8)

    db 0x85, 0x01                   ;//   REPORT_ID (1)
    db 0x95, 0x3f                   ;//   REPORT_COUNT (62)
    db 0x09, 0x00                   ;//   USAGE (Undefined)
    db 0xb2, 0x02, 0x01             ;//   FEATURE (Data,Var,Abs,Buf)

    db 0x85, 0x02                   ;//   REPORT_ID (2)
    db 0x95, 0x3f                   ;//   REPORT_COUNT (30)
    db 0x09, 0x00                   ;//   USAGE (Undefined)
    db 0xb2, 0x02, 0x01             ;//   FEATURE (Data,Var,Abs,Buf)

    db 0xc0                         ;// END_COLLECTION
;; };
USB_HID_RPT_end


#endif

	extern	USB_LANG_DESC
;-----------------------------------------------------------------------------
; String descriptors language ID Descriptor
;USB_LANG_DESC
;USB_LANG_DESC_bLength	db	(USB_LANG_DESC_end - USB_LANG_DESC)	; Size
;USB_LANG_DESC_bDscType	db	DSC_STR	; Descriptor type = string
;USB_LANG_DESC_string	dw	0x0409	; Language ID = EN_US
;USB_LANG_DESC_end
;-----------------------------------------------------------------------------
; Manufacturer string Descriptor
USB_MFG_DESC
USB_MFG_DESC_bLength	db	(USB_MFG_DESC_end - USB_MFG_DESC)	; Size
USB_MFG_DESC_bDscType	db	DSC_STR	; Descriptor type = string
;;			dw	'Y','C','I','T'
			dw	'A','V','R','e','t','c'
USB_MFG_DESC_end
;-----------------------------------------------------------------------------
; Product string Descriptor
#if USE_PROD_STRING
USB_PROD_DESC
USB_PROD_DESC_bLength	db	(USB_PROD_DESC_end - USB_PROD_DESC)	; Size
USB_PROD_DESC_bDscType	db	DSC_STR	; Descriptor type = string
			dw	'P','I','C','1','8','s','p','x'
USB_PROD_DESC_end
#endif

;-----------------------------------------------------------------------------
; Serial Identifier string Descriptor
USB_SER_DESC
USB_SER_DESC_bLength	db	(USB_SER_DESC_end - USB_SER_DESC)	; Size
USB_SER_DESC_bDscType	db	DSC_STR	; Descriptor type = string
			dw	'0','0','0','3'
USB_SER_DESC_end
;-----------------------------------------------------------------------------
;	�Q�ƃe�[�u��.	:: ����! ���̃e�[�u����code�y�[�W���ׂ��ł͂Ȃ�Ȃ�.
;-----------------------------------------------------------------------------
	global	desc_tab
desc_tab
	dw	USB_DEV_DESC
	db	(USB_DEV_DESC_end - USB_DEV_DESC)	; Size
	dw	USB_CFG_DESC
	db	(USB_CFG_DESC_Total_end - USB_CFG_DESC) 	; Size
	dw	USB_HID_DESC
	db	(USB_HID_DESC_end - USB_HID_DESC)	; Size

	dw	USB_HID_RPT
	db	(USB_HID_RPT_end - USB_HID_RPT)		; Size
	dw	USB_LANG_DESC
	db	4	;;(USB_LANG_DESC_end - USB_LANG_DESC)	; Size
	dw	USB_MFG_DESC
	db	(USB_MFG_DESC_end - USB_MFG_DESC)	; Size
	dw	USB_PROD_DESC
	db	(USB_PROD_DESC_end - USB_PROD_DESC)	; Size
	dw	USB_SER_DESC
	db	(USB_SER_DESC_end - USB_SER_DESC)	; Size

;-----------------------------------------------------------------------------
USB_DESC_END_SECTION
;-----------------------------------------------------------------------------
	END
