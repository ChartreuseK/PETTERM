#define SERIALTERMINAL      "/dev/ttyUSB0"
#include <errno.h>
#include <fcntl.h> 
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <ctype.h>

static struct termios orig_termios;  /* TERMinal I/O Structure */
static int ttyfd = STDIN_FILENO;     /* STDIN_FILENO is 0 by default */
#define BLEN    1024
unsigned char rbuf[BLEN];
unsigned char *rp = &rbuf[BLEN];
int bufcnt = 0;

int DEBUG = 1; // DEBUG FLAG


/* increment two-byte memory pointer */
   void inc_pointer(int *lo, int *hi) {
      (*lo)++;
      if ((*lo) == 256) {
	 (*lo) = 0;
	 (*hi)++;
      }
      return;
   } 

/* get a byte from intermediate buffer of serial terminal */
   static unsigned char rx_pet(int fd)
   {
      FILE* fout;
      FILE* fin;

      char header[5] = "000";
      char op_save[5] = "SAVE";
      char op_load[5] = "LOAD";
      unsigned char *rbufptr;
      int buf_ix = 0;

      int eot = 0;
      int headflg = 0;
      int saveflg = 0;
      int loadflg = 0;

      int nextflg = 0;
      int curlo = 0, curhi = 0;
      int nextlo = 0, nexthi = 0;

      fout = fopen("pet_basic.seq", "wb");

      bufcnt = read(fd, rbuf, BLEN);

      while (eot == 0 && bufcnt > 0) {
	 buf_ix = 0;
	 /* buffer needs refill */
	 rbufptr = rbuf;

	 if (DEBUG) printf("\n\n ***** Read %d bytes.\n\n", bufcnt);
	 if (DEBUG) printf("   ");
	 for (int i = 0; i < bufcnt; i++) {
	    if (DEBUG) printf("0x%02x ", rbuf[i]);
	 }

	 if (headflg == 0) {
	    if (strncmp(header, rbuf, 3)) {
	       if (DEBUG) printf("\n\n   Found header.\n\n");
	       headflg = 1;
	    } else {
	       printf("ERROR: Invalid data format!\n\n");
	       exit(1);
	    }
	 }

	 if (headflg == 1) {

	    rbufptr += 3;
	    buf_ix += 3;

	    if (strncmp(op_save, rbuf, 4)) {
	       printf("\nSAVE operation requested.\n");
	       saveflg = 1;
	    } else if (strncmp(op_load, rbuf, 4)) {
	       printf("\nLOAD operation requested.\n");
	       loadflg = 1;
	    } else {
	       printf("ERROR: Invalid operation requested!\n\n");
	       exit(1);
	    } 

	    rbufptr += 4;
	    buf_ix += 4;
	    headflg = 2;

	 }

	 if (DEBUG) printf("\n   Writing pet_basic.seq from serial data...\n");
	 for (int i = buf_ix; i < bufcnt; i++) {

	    if (curlo == 0 && curhi == 0) {

	       // Begin saving now.
	       
	       // Get and write SOB bytes (current pointer bytes) first.
	       curlo = rbuf[buf_ix];
	       curhi = rbuf[buf_ix+1];

	       if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix]);
               if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix+1]);
	       fwrite(&rbuf[buf_ix],1,1,fout);
               fwrite(&rbuf[buf_ix+1],1,1,fout);

	       rbufptr += 2;
	       buf_ix += 2;

	       // Jump iterator 'i' by two.
	       i += 2;

               // Get and write next pointer.

               nextlo = rbuf[buf_ix];
               nexthi = rbuf[buf_ix+1];

               if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix]);
               if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix+1]);
               fwrite(&rbuf[buf_ix],1,1,fout);
               fwrite(&rbuf[buf_ix+1],1,1,fout);
               rbufptr += 2;
               buf_ix += 2;

	       // Jump iterator 'i' by one.
	       i++;

	       // Increment pointer by 2.
	       inc_pointer(&curlo, &curhi);
               inc_pointer(&curlo, &curhi);

	    } else {

	       if (nextflg != 1 && curlo == nextlo && curhi == nexthi) {

                  if (DEBUG) printf("\n   Ready to read the next line.\n");

                  // Get and write next pointer.
                  nextlo = rbuf[buf_ix];
   
                  if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix]);
                  fwrite(&rbuf[buf_ix],1,1,fout);
                  rbufptr += 1;
                  buf_ix += 1;
   
                  inc_pointer(&curlo, &curhi);

		  nextflg = 1;

	       } else if (nextflg == 1) {
  
                  // Get and write next pointer.
                  nexthi = rbuf[buf_ix];

                  if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix]);
                  fwrite(&rbuf[buf_ix],1,1,fout);
                  rbufptr += 1;
                  buf_ix += 1;

                  inc_pointer(&curlo, &curhi);
		  nextflg = 0;
 
	       } else {


                  if (DEBUG) printf("\n   NextLo: 0x%02x\n", nextlo);
                  if (DEBUG) printf("\n   NextHi: 0x%02x\n", nexthi);
                  if (DEBUG) printf("\n   CurLo: 0x%02x\n", curlo);
                  if (DEBUG) printf("\n   CurHi: 0x%02x\n", curhi);

		  // Save next byte and increment pointer.
                  if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[buf_ix]);
                  fwrite(&rbuf[buf_ix],1,1,fout);
                  rbufptr += 1;
                  buf_ix += 1;
                  inc_pointer(&curlo, &curhi);
	       }

	    } // Receiving and writing program.

	 } // Looping current buffer.

	 if (DEBUG) printf("\n");
	 if (nextlo == 0 && nexthi == 0) {
	    eot = 1;
	 }

	 if (bufcnt <= 0) {
	    /* report error, then abort */
	    printf ("Read buffer empty.\n");
	    exit(1);
	 }

	 if (eot == 0) {
	    bufcnt = read(fd, rbuf, BLEN);
	 }

      } // Loop on more buffer data.

      // Write final 0 byte.
      //if (DEBUG) printf("\n   Writing final byte: 0x%02x\n", rbuf[buf_ix]);
      //fwrite(&rbuf[buf_ix],1,1,fout);

      fclose(fout);
      printf("\nFile received and saved.\n");

      if (DEBUG) printf("\n   Reading pet_basic.seq for verification...\n\n");
      fin = fopen("pet_basic.seq", "rb");

      char buffer[1];
      int rcount = 0;
      if (fin) {
	 /* File was opened successfully. */

	 /* Attempt to read */
	 if (DEBUG) printf("   ");
	 while (rcount = fread(buffer, 1,1, fin) > 0) {
	    if (DEBUG) printf("0x%02x ", buffer[0]);
	 }
	 if (DEBUG) printf("\n\n");
	 fclose(fin);
      }

      return *rp++;
   }


   /* send a byte from intermediate buffer of serial terminal */
   static unsigned char tx_pet(int fd, char *filename)
   {
      FILE* fin;

      if (DEBUG) printf("\n   Reading %s for loading...\n\n", filename);
      fin = fopen(filename, "rb");

      char buffer[2];
      char end_ptr[2];
      char eot[8] = "\0\0\0\0\0\0\0\0";
      int sz = 0;
      int rcount = 0;
      unsigned char sob_lo, sob_hi;
      unsigned int bcount = 0;
      if (fin) {

         fseek(fin, 0L, SEEK_END);
         sz = ftell(fin);
	 rewind(fin);

	 if (DEBUG) printf("File size: %d bytes.\n", sz);

	 /* File was opened successfully. */

	 /* Attempt to read */
	 if (DEBUG) printf("   ");
         while (rcount = fread(buffer, 1,1, fin) > 0) {
	    if (bcount > 1) { // skip first two bytes


               if (bcount == 2) {

		  // This is the first program byte. Send the end pointer now.
		  int sob = (int)(((unsigned)sob_hi << 8) | sob_lo );
		  sz -= 2;

		  if (DEBUG) printf("\nProgram data size: %d\n", sz);
		  if (DEBUG) printf("Start of BASIC: %d\n", sob);

                  sz += sob; // Add program data size to SOB for End Pointer Address.

                  unsigned char lsb = (unsigned)sz & 0xff; // mask the lower 8 bits
                  unsigned char msb = (unsigned)sz >> 8;   // shift the higher 8 bits
         
                  if (DEBUG) printf("Sending: 0x%02x 0x%02x ", lsb, msb);
         
                  end_ptr[0] = lsb;
                  end_ptr[1] = msb;
                  write(fd, &end_ptr[0], 1);
                  write(fd, &end_ptr[1], 1);
                  usleep(200000);

	       }

               if (DEBUG) printf("0x%02x ", buffer[0]);
               write(fd, &buffer[0], 1);
               usleep(200000);
   	    } else {
	       if (bcount == 0) {
                  sob_lo = buffer[0];
	       } else {
		  sob_hi = buffer[0];
	       }
	    }
	    bcount++;
         }
         // kludge to flush with three null characters 
         for (int i=0; i < 3; i++) {
            write(fd, &eot[i], 1);
            usleep(200);
         }
         tcdrain(fd);
         if (DEBUG) printf("\n\n");
         fclose(fin);
      }

      return *rp++;
}


int set_interface_attribs(int fd, int speed, int canonical)
{
   struct termios tty;

   if (tcgetattr(fd, &tty) < 0) {
      printf("Error from tcgetattr: %s\n", strerror(errno));
      return -1;
   }

   if (canonical == 0) {
      cfmakeraw(&tty);
   }

   cfsetospeed(&tty, (speed_t)speed);
   cfsetispeed(&tty, (speed_t)speed);

   tty.c_cflag |= CLOCAL | CREAD;
   tty.c_cflag &= ~PARENB;     /* no parity bit */
   tty.c_cflag &= ~CSTOPB;     /* only need 1 stop bit */
   tty.c_cflag &= ~CSIZE;
   tty.c_cflag &= ~CRTSCTS;    /* no hardware flowcontrol */
   tty.c_cflag |= CS8;         /* 8-bit characters */

   if (canonical == 1) {
      tty.c_lflag |= ICANON | ISIG;  /* canonical input */
   }
   tty.c_lflag &= ~(ECHO | ECHOE | ECHONL | IEXTEN);

   tty.c_iflag &= ~IGNCR;  /* preserve carriage return */
   //tty.c_iflag |= ICRNL;
   tty.c_iflag &= ~INPCK;
   //tty.c_iflag &= ~(INLCR | ICRNL | IUCLC | IMAXBEL);
   tty.c_iflag &= ~(IXON | IXOFF | IXANY);   /* no SW flowcontrol */

   //tty.c_oflag |= ONLCR; /* translate newline to NL-CR pair */
   //tty.c_oflag |= NLDLY / NL1;
   tty.c_oflag |= CRDLY / CR3; /* carriage-return delay */
   tty.c_oflag &= ~OPOST;

   tty.c_cc[VEOL] = 0;
   tty.c_cc[VEOL2] = 0;
   tty.c_cc[VEOF] = 0x04;

   if (tcsetattr(fd, TCSANOW, &tty) != 0) {
      printf("Error from tcsetattr: %s\n", strerror(errno));
      return -1;
   }
   return 0;
}



char * strupr(char * temp) {
  char * name;
  name = strtok(temp,":");

  // Convert to upper case
  char *s = name;
  while (*s) {
    *s = toupper((unsigned char) *s);
    s++;
  }
  return s;
}

int main(int argc, char **argv)
{
   char *portname = SERIALTERMINAL;
   char *filename;
   int wlen;
   int rlen;
   unsigned char ibuf[64];
   unsigned char p;
   int plen;
   int fd;

   if (argc < 2) {
      fprintf(stdout, "usage: %s <SAVE/LOAD> [file]\n", argv[0]);
      exit(1);
   }

   filename = (char *)malloc(sizeof(char)*256);

   fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
   if (fd < 0) {
      printf("Error opening %s: %s\n", portname, strerror(errno));
      return -1;
   }
   /*baudrate 1200, 8 bits, no parity, 1 stop bit */
   set_interface_attribs(fd, B1200, 0);

   /*
   write(fd,"DATA ", 8);
   usleep(100);
   write(fd, "GATEWAY ", 8);
   usleep(100);
   write(fd, "ACTIVE\n\n", 8);
   */

   do {

      // POC : Testing BASIC program SAVE/LOAD.
      strupr(argv[1]);
      if (strcmp(argv[1],"LOAD") == 0) {
	 if (argc < 3) {
            fprintf(stdout, "usage: %s LOAD <file>\n", argv[0]);
            exit(1);
	 }
	 strcpy(filename, argv[2]);
         p = tx_pet(fd, filename);
      } else if (strcmp(argv[1],"SAVE") == 0) {
	 p = rx_pet(fd);
      } else {
          fprintf(stderr, "ERROR: unknown method %s\n", argv[1]);
	  exit(1);
      }

      close(fd);
      exit(0); // POC : Bail for now...

      plen = read(fd, &p, 1);
      plen = 1;
      printf("Got byte.\n");
      if (plen > 0) {
         /* first display as hex numbers then ASCII */
         printf(" 0x%x", p);
         /*
            if (p == 4) {
            printf("\n\nBye bye.\n");
            exit(0);
            }
            */
         if (p >= ' ') {
            printf("\n    \"%c\"\n\n", p);
         } else {
            printf("\n    \".\"\n\n");
         } 
      } else if (plen < 0) {
         printf("Error from read: %d: %s\n", plen, strerror(errno));
      } else {  /* plen == 0 */
         printf("Nothing read. EOF?\n");
      }
      if (p == 0x13) {
         //printf("\n\n***** C64 XOFF ******\n\n");
         do {
            plen = read(fd, &p, 1);
            //printf("Got byte.\n");
            if (plen > 0) {
               /* first display as hex numbers then ASCII */
               printf(" 0x%x", p);
               if (p == 4) {
                  printf("\n\nBye bye.\n");
                  exit(0);
               }
               if (p >= ' ') {
                  printf("\n    \"%c\"\n\n", p);
               } else if (p == 0x11) {
                  printf("\n\n***** C64 XON *****\n\n");
               } else{
                  printf("\n    \".\"\n\n");
               }
            } else if (plen < 0) {
               printf("Error from read: %d: %s\n", plen, strerror(errno));
            } else {  /* plen == 0 */
               printf("Nothing read. EOF?\n");
            }
         } while (p != 0x11); /* while (p != XON) */
      } /* if (p == XOFF) */
   } while(1);
}

