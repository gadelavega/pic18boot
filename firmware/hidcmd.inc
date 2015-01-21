;//
;//	HIDcmd

;//======================================================================
; // Basic policy
; // Common command 0x00 ~ 0x0f
; // PIC writer 0x10 ~ 0x1f
; // AVR writer 0x20 ~ 0x2f
; // LSB = 1 (odd number) command, returns essentially reply packet.
;//======================================================================

;//	Common Commands
#define HIDASP_TEST       0x01	;//Connection test
#define HIDASP_BOOT_EXIT  0x03	;//Exit the bootloader, to start the application.
#define HIDASP_POKE       0x04	;//Memory write.
#define HIDASP_PEEK       0x05	;//Memory read.
#define HIDASP_JMP        0x06	;//Program execution of the specified address.

;//	PICmon dedicated command
#define HIDASP_SET_MODE       0x07  ;//Specification of data take-off mode (00 = poll c0 = puts c9 = exit)
#define HIDASP_PAGE_ERASE     0x08  ;//Flash erase.
#define HIDASP_KEYINPUT       0x09  ;//Send the host side of the keyboard.
#define HIDASP_PAGE_WRITE     0x0a  ;//Flash write.

;//  Not implemented in PIC
#define HIDASP_BOOT_RWW      0x0b	;//Allow the code reading application areas.
#define HIDASP_USER_CMD      0x0c	;//Run a user-defined command.
#define HIDASP_GET_STRING    0x0d	;//Get the string.

;//	PIC writer system (0x10 ~ 0x1f) 
;//======================================================================
#define PICSPX_SETADRS24      0x10	;// Set 24bit address of the TBLPTR.
;// SETADRS24 [ CMD ] [ --- ] [ADRL] [ADRH] [ADRU] 
#define PICSPX_GETDATA8L      0x11	;// Get the 8bit data column.
;// GETDATA8L [ CMD ] [ LEN ] [ADRL] [ADRH] [ADRU] 
#define PICSPX_SETCMD16L      0x12	;// Write the 16bit data column.
;// SETCMD16L [ CMD ] [ LEN ] [ADRL] [ADRH] [ADRU] [CMD4] [ MS ] data[32]
#define PICSPX_BITBANG        0x14	;// MCLR,PGM,PGD,PGC: control each bit.
;// BITBANG   [ CMD ] [ LEN ] data[60]
#define PICSPX_BITREAD        0x15	;// MCLR,PGM,PGD,PGC: controls each bit, read results to return.
;// BITREAD   [ CMD ] [ LEN ] data[60]


#define PICSPX_WRITE24F       0x16	;// PIC24F write data column.
#define PICSPX_READ24F        0x17	;// PIC24F read data column.

;//	Unimplemented.


;//	AVR write command (Fusion)
;//======================================================================
;// +0      +1      +2        +3         +35
;//[ID] [HIDASP_PAGE_TX_*] [len=32] [data(32)] [ isp(4) ]
#define HIDASP_PAGE_TX        0x20	;//MODE=00
#define HIDASP_PAGE_RD        0x21	;//MODE=01
#define HIDASP_PAGE_TX_START  0x22	;//MODE=02  ADDR 初期化.
#define HIDASP_PAGE_TX_FLUSH  0x24	;//MODE=04  転送後 ISP
;//                            0x27 まではPAGE_TXで使用する.

#define CMD_MASK              0xf8	;//AVR書き込みコマンドの検出マスク.
#define MODE_MASK             0x07	;//AVR書き込みコマンドの種別マスク.

;//	AVR書き込みコマンド(Control)
#define HIDASP_CMD_TX         0x28	;//ISPコマンドを4byte送る.
#define HIDASP_CMD_TX_1       0x29	;//ISPコマンドを4byte送って、結果4byteを受け取る.
#define HIDASP_SET_PAGE       0x2a	;//AVRのページアドレスをセットする.
#define HIDASP_SET_STATUS     0x2b	;//AVRライターモードの設定
#define HIDASP_SET_DELAY      0x2c	;//SPI書き込み遅延時間の設定.
#define HIDASP_WAIT_MSEC      0x2e	;//1mS単位の遅延を行う.

;//デバイスID
#define	DEV_ID_FUSION			0x55
#define	DEV_ID_STD				0x5a
#define	DEV_ID_MEGA88			0x88
#define	DEV_ID_MEGA88_USERMODE	0x89
#define	DEV_ID_PIC				0x25
#define	DEV_ID_PIC18F14K		0x14


#define	POLL_NONE				0
#define	POLL_ANALOG				0xa0
#define	POLL_DIGITAL			0xa0
#define	POLL_PORT				0xc0
#define	POLL_PRINT				0xc1
#define	POLL_END				0xc9

#if	0
/*
 * ドキュメント

  +--------------+-------------------------------------------------------------+
  |   コマンド   |  パラメータ              | 動作                             |
  +--------------+-----------+-------------------------------------------------+
  |TEST          | ECHO      |          ＝接続チェックを行う.
  +--------------+-----------+--------+----------------------------------------+
  |SET_STATUS    | PORTD     | PORTB  | ＝LED制御を行う.
  +--------------+-----------+--------+----------------------------------------+
  |CMD_TX        | ISP_COMMAND[4]           | ＝ISPコマンドを４バイト送信
  +--------------+--------------------------+----------------------------------+
  |CMD_TX_1      | ISP_COMMAND[4]           | ＝ISPコマンドを４バイト送信して受信
  +--------------+-----------+--------------+----------------------------------+
  |SET_PAGE      | PAGE_MODE |   ＝ページモードの初期化とアドレスリセット
  +--------------+-----------+-------------------------------------------------+
  |PAGE_TX       | LENGTH    |   DATA[ max 32byte ]       | ＝ページモード書き込み
  +--------------+-----------+-------------------------------------------------+
  |PAGE_RD       | LENGTH    |                              ＝ページモード読み出し
  +--------------+-----------+-------------------------------------------------+
  |PAGE_TX_START | LENGTH    |   DATA[ max 32byte ]       | ＝ページモードの初期化とページモード書き込み
  +--------------+-----------+-------------------------------------------------+
  |PAGE_TX_FLUSH | LENGTH    |   DATA[ 32byte 固定]       | ISP_COMMAND[4]    | ＝ページモード書き込み後Ｆｌｕｓｈ書き込み実行.
  +--------------+-----------+-------------------------------------------------+
  |SET_DELAY     | delay     |   ＝ＳＰＩクロック速度の設定(delay=0..255).
  +--------------+-----------+------------+-------+-------+--------------------+
  |POKE          | count     | address[2] | data0 | data1 | ＝内蔵ＲＡＭ書き込み
  +--------------+-----------+------------+-------+-------+--------------------+
  |PEEK          | count     | address[2] |                 ＝内蔵ＲＡＭ読み出し
  +--------------+-----------+-------------------------------------------------+

 *注1: PAGE_TX_STARTとPAGE_TX_FLUSHはどちらもPAGE_TXに対する修飾ビットなので、
       両方を併せ持つパケットも作成可能です。

 *注2: コマンドのLSBが１になっている場合はコマンド実行後、読み取りフェーズが実行されます。
       読み取りサイズは、ホスト側から指定されます。

  応答フェーズで返却されるパケットの構造
  +--------------+-------------------------------------------------------------+
  |   コマンド   |  返却値                                                     |
  +--------------+-----------+----------+--------------------------------------+
  |TEST          | DEV_ID    | ECHO     |           ＝接続チェック.
  +--------------+-----------+----------+---+----------------------------------+
  |CMD_TX_1      | ISP_COMMAND[4]           | ＝ISPコマンド実行結果.
  +--------------+--------------------------+----------------------------------+
  |PAGE_RD       | DATA[ max 38byte ]       | ＝ページモード読み出しデータ.
  +--------------+--------------------------+----------------------------------+
  |PEEK          | DATA[ max 8 byte ]       | ＝内蔵ＲＡＭ読み出しデータ.
  +--------------+--------------------------+----------------------------------+

 *注3: HID Reportは先頭に必ずReportIDが入るため、
       上記返却値は HID Reportの２バイト目以降の意味となります。

 *注4: DEV_ID は現在の版では、以下の値のどちらかです。 
		0x55 : フュージョンありファームウェア
		0x5A : フュージョンなしファームウェア
       ECHOは渡された値をそのまま返します.


*/
#endif

