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
   int lenflg = 0;
   int saveflg = 0;
   int loadflg = 0;

   int blen = 0;
   int bsavcnt = 0;

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

      if (headflg == 1 && lenflg == 0) {

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

         lenflg = 1;

         rbufptr += 4;
         buf_ix += 4;

         if (saveflg == 1) {
            blen = rbufptr[0];
            rbufptr++;
            blen += rbufptr[0] * 256;
            buf_ix += 2;
            printf("BASIC program length = %d bytes.\n", blen);
         }
      }

      if (DEBUG) printf("\n   Writing pet_basic.seq from serial data...\n");
      for (int i = buf_ix; i < bufcnt; i++) {
         if (DEBUG) printf("\n   Writing: 0x%02x\n", rbuf[i]);
         fwrite(&rbuf[i],1,1,fout);
         bsavcnt++;
      }
      if (DEBUG) printf("\n");
      if (bsavcnt >= blen) {
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

   }

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
static unsigned char tx_pet(int fd)
{
   FILE* fin;

   if (DEBUG) printf("\n   Reading pet_basic.seq for loading...\n\n");
   fin = fopen("pet_basic.seq", "rb");

   char buffer[1];
   int rcount = 0;
   if (fin) {
      /* File was opened successfully. */

      /* Attempt to read */
      if (DEBUG) printf("   ");
      while (rcount = fread(buffer, 1,1, fin) > 0) {
         if (DEBUG) printf("0x%02x ", buffer[0]);
	 write(fd, &buffer[0], 1);
         usleep(100);
      }
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

   tty.c_oflag |= ONLCR; /* translate newline to NL-CR pair */
   //tty.c_oflag |= NLDLY / NL1;
   tty.c_oflag |= CRDLY / CR3; /* carriage-return delay */
   //tty.c_oflag &= ~OPOST;

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
   int wlen;
   int rlen;
   unsigned char ibuf[64];
   unsigned char p;
   int plen;
   int fd;

   if (argc < 2) {
      fprintf(stderr, "usage: %s <SAVE/LOAD>\n", argv[0]);
      exit(1);
   }

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
         p = tx_pet(fd);
      } else if (strcmp(argv[1],"SAVE") == 0) {
	 p = rx_pet(fd);
      } else {
          fprintf(stderr, "ERROR: unknown method %s\n", argv[1]);
	  exit(1);
      }
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

