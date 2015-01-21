/*********************************************************************
 *	P I C b o o t
 *********************************************************************
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#ifndef	_LINUX_
#include <windows.h>
#endif


#define MAIN_DEF	// for monit.h
#include "monit.h"
#include "hidasp.h"
#include "util.h"

#define CMD_NAME "picboot.exe"
#define DEFAULT_SERIAL	"*"

char HELP_USAGE[]={
	"* PICboot Ver 0.3 (" __DATE__ ")\n"
	"Usage is\n"
	"  " CMD_NAME " [Options] <hexfile.hex>\n"
	"Options\n"
	"  -p[:XXXX]   ...  Select serial number (default=" DEFAULT_SERIAL ").\n"
	"  -r          ...  Run after write.\n"
	"  -v          ...  Verify.\n"
	"  -E          ...  Erase.\n"
	"  -rp         ...  Read program area.\n"
	"  -nv         ...  No-Verify.\n"
	"  -B          ...  Allow Bootloader Area to Write / Read !.\n"
	"  -sXXXX      ...  Set program start address. (default=0700)\n"
};

#define	MAX_CMDBUF	4096

static	char lnbuf[1024];
static	char usb_serial[128]=DEFAULT_SERIAL;	/* �g�p����HIDaspx�̃V���A���ԍ����i�[ */
static	char verbose_mode = 0;	//1:�f�o�C�X�����_���v.
		int  hidmon_mode = 1;	/* picmon �����s�� */
static	uchar 	databuf[256];
static	int		dataidx;
static	int		adr_u = 0;		// hexrec mode 4


#define	FLASH_START	0x0700
#define	FLASH_SIZE	0x10000
#define	FLASH_STEP	32
#define	ERASE_STEP	256

#define	FLASH_OFFSET 0		// 0x700 = �e�X�g.

static	uchar flash_buf[FLASH_SIZE];
static	int	  flash_start = FLASH_START;
static	int	  flash_end   = FLASH_SIZE;
static	int	  flash_end_for_read = 0x8000;

#define	CACHE_SIZE	64
static	uchar cache_buf[CACHE_SIZE];
static	int   cache_addr=(-1);

static	char  opt_r  = 0;		//	'-r '
static	char  opt_rp = 0;		//	'-rp'
static	char  opt_re = 0;		//	'-re'
static	char  opt_rf = 0;		//	'-rf'

static	char  opt_E  = 0;		//	erase
static	char  opt_v  = 0;		//	'-v'
static	char  opt_nv = 0;		//	'-nv'

//	���[�U�[�A�v���P�[�V�����J�n�Ԓn.
static	int   opt_s  = 0x700;	//	'-s1000 �Ȃ�'

#define	CHECKSUM_CALC	(1)


#define	DEVCAPS_BOOTLOADER	0x01

void hidasp_delay_ms(int dly);
/*********************************************************************
 *	�g�p�@��\��
 *********************************************************************
 */
void usage(void)
{
	fputs( HELP_USAGE, stdout );
}
/*********************************************************************
 *	��s���̓��[�e�B���e�B
 *********************************************************************
 */
static	int getln(char *buf,FILE *fp)
{
	int c;
	int l;
	l=0;
	while(1) {
		c=getc(fp);
		if(c==EOF)  {
			*buf = 0;
			return(EOF);/* EOF */
		}
		if(c==0x0d) continue;
		if(c==0x0a) {
			*buf = 0;	/* EOL */
			return(0);	/* OK  */
		}
		*buf++ = c;l++;
		if(l>=255) {
			*buf = 0;
			return(1);	/* Too long line */
		}
	}
}
/**********************************************************************
 *	INTEL HEX���R�[�h �`��01 ���o�͂���.
 **********************************************************************
 */
static	int	out_ihex01(unsigned char *data,int adrs,int cnt,FILE *ofp)
{
	int length, i, sum;
	unsigned char buf[1024];

	buf[0] = cnt;
	buf[1] = adrs >> 8;
	buf[2] = adrs & 0xff;
	buf[3] = 0;

	length = cnt+5;
	sum=0;

	memcpy(buf+4,data,cnt);
	for(i=0;i<length-1;i++) {
		sum += buf[i];
	}
	sum = 256 - (sum&0xff);
	buf[length-1] = sum;

	fprintf(ofp,":");
	for(i=0;i<length;i++) {
		fprintf(ofp,"%02X",buf[i]);
	}
	fprintf(ofp,"\n");
	return 0;
}
/**********************************************************************
 *	INTEL HEX���R�[�h �`��01 (�o�C�i���[���ς�) �����߂���.
 **********************************************************************
 */
#if	0
static void put_flash_buf(int adrs,int data)
{
	adrs = adrs - FLASH_BASE;
	if( (adrs >= 0) && (adrs < FLASH_SIZE ) ) {
		flash_buf[adrs] = data;
	}
}
#endif
/**********************************************************************
 *	INTEL HEX���R�[�h �`��01 (�o�C�i���[���ς�) �����߂���.
 **********************************************************************
 */
static	int	parse_ihex01(unsigned char *buf,int length)
{

	int adrs = (buf[1] << 8) | buf[2];
	int cnt  =  buf[0];
	int i;
	int sum=0;

#if	CHECKSUM_CALC
	for(i=0;i<length;i++) {
		sum += buf[i];
	}
//	printf("checksum=%x\n",sum);
	if( (sum & 0xff) != 0 ) {
		fprintf(stderr,"%s: HEX RECORD Checksum Error!\n", CMD_NAME);
		exit(EXIT_FAILURE);
	}
#endif

	buf += 4;

#if	HEX_DUMP_TEST
	printf("%04x",adrs|adr_u);
	for(i=0;i<cnt;i++) {
		printf(" %02x",buf[i]);
	}
	printf("\n");
#endif


	if(adr_u != 0) return 1;	//��ʃA�h���X����[��(64kB�ȊO)

	for(i=0;i<cnt;i++) {
		flash_buf[adrs+i] = buf[i];
	}
	return 0;
}
/**********************************************************************
 *	INTEL HEX���R�[�h(�P�s:�o�C�i���[���ς�) �����߂���.
 **********************************************************************
 */
int	parse_ihex(int scmd,unsigned char *buf,int length)
{
	switch(scmd) {
		case 0x00:	//�f�[�^���R�[�h:
					//�f�[�^�t�B�[���h�͏������܂��ׂ��f�[�^�ł���B
			return parse_ihex01(buf,length);

		case 0x01:	//�G���h���R�[�h:
					//HEX�t�@�C���̏I��������.�t����񖳂�.
			return scmd;
			break;

		case 0x02:	//�Z�O�����g�A�h���X���R�[�h:
					//�f�[�^�t�B�[���h�ɂ̓Z�O�����g�A�h���X������B ���Ƃ��΁A
					//:02000002E0100C
					//		   ~~~~
					//
			break;

		case 0x03:	//�X�^�[�g�Z�O�����g�A�h���X���R�[�h.
			break;

		case 0x04:	//�g�����j�A�A�h���X���R�[�h.
					//���̃��R�[�h�ł�32�r�b�g�A�h���X�̂������16�r�b�g
					//�i�r�b�g32�`�r�b�g16�́j��^����B
				adr_u = (buf[4]<<24)|(buf[5]<<16);
//				printf("adr_u=%x\n",adr_u);
				return scmd;
			break;

		case 0x05:	//�X�^�[�g���j�A�A�h���X�F
					//�Ⴆ��
					//:04000005FF000123D4
					//         ~~~~~~~~
					//�ƂȂ��Ă���΁AFF000123h�Ԓn���X�^�[�g�A�h���X�ɂȂ�B

			break;

	}
	fprintf(stderr,"Unsupported ihex cmd=%x\n",scmd);
	return 0;
}

/**********************************************************************
 *	16�i2���̕�������o�C�i���[�ɕϊ�����.
 **********************************************************************
 */
int read_hex_byte(char *s)
{
	char buf[16];
	int rc = -1;

	buf[0] = s[0];
	buf[1] = s[1];
	buf[2] = 0;
	sscanf(buf,"%x",&rc);
	return rc;
}

/**********************************************************************
 *	16�i�ŏ����ꂽ��������o�C�i���[�ɕϊ�����.
 **********************************************************************
 */
static	int read_hex_string(char *s)
{
	int rc;

	dataidx = 0;
	while(*s) {
		rc = read_hex_byte(s);s+=2;
		if(rc<0) return rc;
		databuf[dataidx++]=rc;
	}
	return 0;
}

/**********************************************************************
 *
 **********************************************************************
 0 1 2 3 4
:1000100084C083C082C081C080C07FC07EC07DC0DC
 ~~ �f�[�^��
   ~~~~ �A�h���X
       ~~ ���R�[�h�^�C�v
         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~�f�[�^
                                         ~~�`�F�b�N�T��.
 */
int	read_ihex(char *s)
{
	int c;
	if(s[0] == ':') {
		read_hex_string(s+1);
		c = databuf[3];
		parse_ihex(c,databuf,dataidx);
	}
	return 0;
}
/*********************************************************************
 *	HEX file ��ǂݍ���� flash_buf[] �Ɋi�[����.
 *********************************************************************
 */
int	read_hexfile(char *fname)
{
	FILE *ifp;
	int rc;
	Ropen(fname);
	while(1) {
		rc = getln(lnbuf,ifp);
		read_ihex(lnbuf);
		if(rc == EOF) break;
	}
	Rclose();
	return 0;
}

/*********************************************************************
 *	flash_buf[]�̎w��G���A�� 0xff�Ŗ��܂��Ă��邱�Ƃ��m�F����.
 *********************************************************************
 *	���܂��Ă���� 0 ��Ԃ�.
 */
static	int	check_prog_ff(int start,int size)
{
	int i;
	for(i=0;i<size;i++) {
		if(flash_buf[start+i]!=0xff) return 1;
	}
	return 0;
}

/*********************************************************************
 *	flash_buf[]�̎w��G���A�� 0xff�Ŗ��܂��Ă��邱�Ƃ��m�F����.
 *********************************************************************
 *	���܂��Ă���� 0 ��Ԃ�.
 */
static	void modify_jmp( int addr , int dst )
{
	dst >>= 1;
	flash_buf[addr+0] = dst;	// lo(dst)
	flash_buf[addr+1] = 0xef;	// GOTO inst

	flash_buf[addr+2] = dst>>8;	// hi(dst)
	flash_buf[addr+3] = 0xf0;	// bit15:12 = '1'
}

/*********************************************************************
 *	�K�v�Ȃ�Aflash_buf[] �� 0x800,0x808,0x818�Ԓn������������.
 *********************************************************************
 */
void modify_start_addr(int start)
{
	if(start == 0x700) return;	//�f�t�H���g�l�Ȃ̂ŉ������Ȃ�.

	if(start < 0x700) {			// ���[�U�[�v���O�����J�n�Ԓn��0x800�ȑO�ɂ���̂͂�������.
		fprintf(stderr,"WARNING: start address %x < 0x700 ?\n",start);
		return;
	}

	if( check_prog_ff(0x700,0x20) ) {
		fprintf(stderr,"WARNING: Can't write JMP instruction.\n");
		return;
	}

	modify_jmp( 0x700 , start );
	modify_jmp( 0x708 , start + 0x08 );
	modify_jmp( 0x718 , start + 0x18 );

}

/*********************************************************************
 *	�^�[�Q�b�g�̍ċN��.
 *********************************************************************
 */
int reboot_target(void)
{
//	UsbBootTarget(0,1);
	UsbBootTarget(0x700,1);
	return 0;
}

/*********************************************************************
 *	flash_buf[] �̓��e�� �^�[�Q�b�g PIC �ɏ�������.
 *********************************************************************
 */
int	write_block_for_test(int addr,int size)
{
	int i,f=0;
	for(i=0;i<size;i++) {
		if(flash_buf[addr+i]!=0xff) f=1;
	}

	if(f) {
		printf("%04x",addr);
		for(i=0;i<size;i++) {
			printf(" %02x",flash_buf[addr+i]);
		}
		printf("\n");
	}
	return 0;
}
/*********************************************************************
 *	64byte������.
 *********************************************************************
 */
int	erase_block(int addr,int size)
{
	int i,f=0;
	int pages = size / 64;

	for(i=0;i<size;i++) {
		if(flash_buf[addr+i]!=0xff) f=1;
	}

	if((f) || (opt_E)) {
		UsbEraseTargetROM(addr + FLASH_OFFSET,pages);
		Sleep(20);
//		hidasp_delay_ms(20);
	}
	return 0;
}

/*********************************************************************
 *	flash_buf[] �̓��e�� �^�[�Q�b�g PIC �ɏ�������.
 *********************************************************************
 */
int	write_block(int addr,int size)
{
	int i,f=0;
	for(i=0;i<size;i++) {
		if(flash_buf[addr+i]!=0xff) f=1;
	}

	if(f) {
		UsbFlash(addr + FLASH_OFFSET,AREA_PGMEM,flash_buf+addr,size);
		Sleep(3);
//		hidasp_delay_ms(3);
		fprintf(stderr,"Writing ... %04x\r",addr);
#if	0
		for(i=0;i<size;i++) {
			printf(" %02x",flash_buf[addr+i]);
		}
		printf("\n");
#endif
	}
	return 0;
}
/*********************************************************************
 *	 �^�[�Q�b�g PIC �̓��e�� flash_buf[] �ɓǂݍ���.
 *********************************************************************
 */
int	read_block(int addr,uchar *read_buf,int size)
{
	int errcnt=0;
#if	0
	UsbRead(addr+ FLASH_OFFSET,AREA_PGMEM,read_buf,size);
#else
	// Cached.
	if((size==32)&&(addr == (cache_addr+32))) {
		memcpy(read_buf,cache_buf+32,size);
	}else{
		// Uncached.
		UsbRead( addr+ FLASH_OFFSET,AREA_PGMEM,cache_buf,CACHE_SIZE);
		cache_addr = addr;
		memcpy(read_buf,cache_buf,size);
	}
#endif
	return errcnt;
}

#if	0
int	read_block(int addr,int size)
{
	int errcnt=0;
	uchar *read_buf;

	read_buf = &flash_buf[addr] ;
	UsbRead(addr + FLASH_OFFSET,AREA_PGMEM,read_buf,size);
	return errcnt;
}
#endif
/*********************************************************************
 *	flash_buf[] �̓��e�� �^�[�Q�b�g PIC �ɏ�������.
 *********************************************************************
 */
int	verify_block(int addr,int size)
{
	int i,f=0;
	int errcnt=0;
	uchar 	verify_buf[256];
	for(i=0;i<size;i++) {
		if(flash_buf[addr+i]!=0xff) f=1;
	}

	if(f) {
//		UsbRead(addr + FLASH_OFFSET,AREA_PGMEM,verify_buf,size);
		read_block(addr,verify_buf,size);
		for(i=0;i<size;i++) {
			if(flash_buf[addr+i] != verify_buf[i]) {
				errcnt++;
				fprintf(stderr,"Verify Error in %x : write %02x != read %02x\n"
					,addr+i,flash_buf[addr+i],verify_buf[i]);
			}
		}
		fprintf(stderr,"Verifying ... %04x\r",addr);
	}
	return errcnt;
}
/*********************************************************************
 *	FLash�̏���.
 *********************************************************************
 */
int	erase_flash(void)
{
	int i;
	fprintf(stderr,"Erase ... \n");
	for(i=flash_start;i<flash_end;i+= ERASE_STEP) {
		erase_block(i,ERASE_STEP);
	}
	return 0;
}
/*********************************************************************
 *	�_�~�[.
 *********************************************************************
 */
int disasm_print(unsigned char *buf,int size,int adr)
{
	unsigned short *inst = (unsigned short *)buf;
	printf("%04x %04x\n",adr,inst[0]);
	return 2;
}
/*********************************************************************
 *	flash_buf[] �̓��e�� �^�[�Q�b�g PIC �ɏ�������.
 *********************************************************************
 */
int	write_hexdata(void)
{
	int i;
	for(i=flash_start;i<flash_end;i+= FLASH_STEP) {
		write_block(i,FLASH_STEP);
	}
	return 0;
}
/*********************************************************************
 *	flash_buf[] �̓��e�� �^�[�Q�b�g PIC �ɏ�������.
 *********************************************************************
 */
int	verify_hexdata(void)
{
	int i;
	int errcnt = 0;
	cache_addr = (-1);

	fprintf(stderr,"\n");
	for(i=flash_start;i<flash_end;i+= FLASH_STEP) {
		errcnt += verify_block(i,FLASH_STEP);
	}
	return errcnt;
}
/*********************************************************************
 *	�|�[�g���̂���A�h���X�����߂�.�i�_�~�[�����j
 *********************************************************************
 */
int	portAddress(char *s)
{
	return 0;
}

/*********************************************************************
 *	ROM�ǂݏo�����ʂ�HEX�ŏo�͂���.
 *********************************************************************
 */
#define	HEX_DUMP_STEP	16

void print_hex_block(FILE *ofp,int addr,int size)
{
	int i,j,f;
	for(i=0;i<size;i+=HEX_DUMP_STEP,addr+=HEX_DUMP_STEP) {
		f = 0;
		for(j=0;j<HEX_DUMP_STEP;j++) {
			if( flash_buf[addr+j] != 0xff ) {
				f = 1;
			}
		}
		if(f) {

#if	0
			printf(":%04x",addr);
			for(j=0;j<HEX_DUMP_STEP;j++) {
				printf(" %02x",flash_buf[addr+j]);
			}
			printf("\n");
#endif
			out_ihex01(&flash_buf[addr],addr,HEX_DUMP_STEP,ofp);


		}
	}


}
/*********************************************************************
 *	ROM�ǂݏo��.
 *********************************************************************
 */
void read_from_pic(char *file)
{
	int i, progress_on;
	FILE *ofp;
	uchar *read_buf;
	cache_addr = (-1);

//	fprintf(stderr, "Reading...\n");
	 progress_on = 1;
#if 1	/* by senshu */
	if(file != NULL && strcmp(file, "con")==0) {
		ofp=stdout;
		progress_on = 0;
	} else {
		if (file == NULL) {
			 file = "NUL";
		}
		ofp=fopen(file, "wb");
		if(ofp==NULL) {
			fprintf(stderr, "%s: Can't create file:%s\n", CMD_NAME, file);
			exit(1);
		}
	}
#else
	Wopen(file);
#endif
	fprintf(ofp,":020000040000FA\n");
	for(i=flash_start;i<flash_end_for_read;i+= FLASH_STEP) {
#if 1
		if (progress_on)
			fprintf(stderr,"Reading ... %04x\r",i);
#else
		fprintf(stderr,"Reading ... %04x\r",i);
#endif
		read_buf = &flash_buf[i] ;
		read_block(i,read_buf,FLASH_STEP);
		print_hex_block(ofp,i,FLASH_STEP);
		fflush(ofp);
	}
	fprintf(ofp,":00000001FF\n");
#if 1
	if (progress_on)
		fprintf(stderr,"\nRead end address = %04x\n", i-1);
#endif
	Wclose();
}
/*********************************************************************
 *	���C��
 *********************************************************************
 */
void getopt_p(char *s)
{
		if (s) {
			if (*s == ':') s++;
			if (*s == '?') {
				hidasp_list("picmon");
				exit(EXIT_SUCCESS);
			} else if (isdigit(*s)) {
				if (s) {
					int n, l;
					l = strlen(s);
					if (l < 4 && isdigit(*s)) {
						n = atoi(s);
						if ((0 <= n) && (n <= 999)) {
							sprintf(usb_serial, "%04d", n);
						} else {
							if (l == 1) {
								usb_serial[3] = s[0];
							} else if  (l == 2) {
								usb_serial[2] = s[0];
								usb_serial[3] = s[1];
							} else if  (l == 3) {
								usb_serial[1] = s[0];
								usb_serial[2] = s[1];
								usb_serial[3] = s[2];
							}
						}
					} else {
						strncpy(usb_serial, s, 4);
					}
				}
			} else if (*s == '\0'){
				strcpy(usb_serial, DEFAULT_SERIAL);		// -p�݂̂̎�
			} else {
				strncpy(usb_serial, s, 4);
			}
			strupr(usb_serial);
		}
}
/*********************************************************************
 *	���C��
 *********************************************************************
 */
int main(int argc,char **argv)
{
	int errcnt, ret_val,retry;



	//�I�v�V�������.
	Getopt(argc,argv,"i");
	if(IsOpt('h') || IsOpt('?') || IsOpt('/')) {
		usage();
		exit(EXIT_SUCCESS);
	}
	if((argc<2)&& (!IsOpt('r')) && (!IsOpt('E')) && (!IsOpt('p')) ) {
		usage();
		exit(EXIT_SUCCESS);
	}


	if(IsOpt('B')) {					// Boot�G���A�̋����ǂݏ���.
		flash_start = 0;
		flash_end   = FLASH_START;
	}
	if(IsOpt('E')) {
		opt_E = 1;				//������������.
	}
	if(IsOpt('p')) {
		getopt_p(Opt('p'));		//�V���A���ԍ��w��.
	}
	if(IsOpt('s')) {
		sscanf(Opt('s'),"%x",&opt_s);	//�A�v���P�[�V�����̊J�n�Ԓn�w��.
	}
	if(IsOpt('r')) {
		char *r = Opt('r');
		if(r[0]==0  ) opt_r = 1;		//�������݌ナ�Z�b�g���삠��.
		if(r[0]=='p') opt_rp = 1;		//'-rp' flash�̈�̓ǂݍ���.
		if(r[0]=='e') opt_re = 1;		//'-re'
		if(r[0]=='f') opt_rf = 1;		//'-rf'
	}
	if(IsOpt('n')) {
		char *n = Opt('n');
		if(n[0]=='v') opt_nv = 1;		//'-nv' 
	}
	if(IsOpt('v')) {
		opt_v = 1;						//'-v' 
	}


  for(retry=3;retry>=0;retry--) {
	//������.
   if( UsbInit(verbose_mode, 0, usb_serial) == 0) {
		fprintf(stderr, "Try, UsbInit(\"%s\").\n", usb_serial);
		if(retry==0) {
			fprintf(stderr, "%s: UsbInit failure.\n", CMD_NAME);
			exit(EXIT_FAILURE);
		}
   }else{

	if( UsbGetDevID() == DEV_ID_PIC18F14K) {	// 14K50��Flash ROM�T�C�Y�ݒ�.
		flash_end_for_read = 0x3fff;
	}else{
		flash_end_for_read = 0x7fff;	// 0x5fff ... PIC18F2455(24kB)�̏ꍇ
	}
	if((UsbGetDevCaps() & DEVCAPS_BOOTLOADER)) {
		break;		// BOOTLOADER�@�\����.
	}else{
		fprintf(stderr, "Reboot firmware ...\n");
		UsbBootTarget(0x000c,1);
		Sleep(10);
		UsbExit();
	}
   }
   Sleep(2500);
  }

//	Flash_Unlock();


	if((opt_E) && (argc < 2)) {					// ���������̎��s.
		erase_flash();							//  Flash����.
	}

	memset(flash_buf,0xff,FLASH_SIZE);
	ret_val = EXIT_SUCCESS;

	if(argc>=2) {
		if(opt_rp||opt_re||opt_rf) {	// ROM�ǂݏo��.
			read_from_pic(argv[1]);
		}else{
			read_hexfile(argv[1]);		//	HEX�t�@�C���̓ǂݍ���.
			modify_start_addr(opt_s);

			if(IsOpt('v')==0) {			// �x���t�@�C�̂Ƃ��͏������݂����Ȃ�.
				erase_flash();				//  Flash����.
				write_hexdata();			//  ��������.
			}

		  if(opt_nv==0) {
			errcnt = verify_hexdata();	//  �x���t�@�C.
			if(errcnt==0) {
				fprintf(stderr,"\nVerify Ok.\n");
			}else{
				fprintf(stderr,"\nVerify Error. errors=%d\n", errcnt);
				ret_val = EXIT_FAILURE;
			}
		  }
		}
	}
#if 1
	else if (argc==1) {
		if(opt_rp||opt_re||opt_rf) {	// ROM�ǂݏo��.
			read_from_pic(NULL);
		}
	}
#endif

//	Flash_Lock();

	if(opt_r) {
		reboot_target();			//  �^�[�Q�b�g�ċN��.
	}
	UsbExit();
	return ret_val;
}
/*********************************************************************
 *
 *********************************************************************
 */

