#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

static uint8_t mem[65536];
static uint16_t pc,sp;
static uint8_t A,B,C,D,E,H,L;
static uint8_t fs,fz,fa,fp,fc;
static int halted=0;
static int normal_exit=0;
static uint16_t dma=0x80;
static int current_drive=0,current_user=0;
static char workdir[4096]=".";
static char search_names[1024][13]; static int search_n=0, search_i=0;

static uint16_t BC(){return ((uint16_t)B<<8)|C;} static uint16_t DE(){return ((uint16_t)D<<8)|E;} static uint16_t HL(){return ((uint16_t)H<<8)|L;}
static void setBC(uint16_t v){B=v>>8; C=v;} static void setDE(uint16_t v){D=v>>8; E=v;} static void setHL(uint16_t v){H=v>>8; L=v;}
static uint16_t rw(uint16_t a){return mem[a]|((uint16_t)mem[(uint16_t)(a+1)]<<8);} static void ww(uint16_t a,uint16_t v){mem[a]=v;mem[(uint16_t)(a+1)]=v>>8;}
static void push(uint16_t v){sp-=2;ww(sp,v);} static uint16_t pop(){uint16_t v=rw(sp);sp+=2;return v;}
static int parity(uint8_t x){x^=x>>4;x&=0xf;return (0x6996>>x)&1 ? 0:1;} // even parity
static void setzsp(uint8_t v){fz=(v==0);fs=(v>>7)&1;fp=parity(v);} 
static uint8_t flags_pack(){return (fs<<7)|(fz<<6)|(fa<<4)|(fp<<2)|2|fc;}
static void flags_unpack(uint8_t f){fs=(f>>7)&1;fz=(f>>6)&1;fa=(f>>4)&1;fp=(f>>2)&1;fc=f&1;}
static uint8_t getr(int r){switch(r){case 0:return B;case 1:return C;case 2:return D;case 3:return E;case 4:return H;case 5:return L;case 6:return mem[HL()];default:return A;}}
static void setr(int r,uint8_t v){switch(r){case 0:B=v;break;case 1:C=v;break;case 2:D=v;break;case 3:E=v;break;case 4:H=v;break;case 5:L=v;break;case 6:mem[HL()]=v;break;default:A=v;}}
static uint16_t getrp(int rp){switch(rp){case 0:return BC();case 1:return DE();case 2:return HL();default:return sp;}}
static void setrp(int rp,uint16_t v){switch(rp){case 0:setBC(v);break;case 1:setDE(v);break;case 2:setHL(v);break;default:sp=v;}}
static int cond(int n){switch(n){case 0:return !fz;case 1:return fz;case 2:return !fc;case 3:return fc;case 4:return !fp;case 5:return fp;case 6:return !fs;default:return fs;}}
static uint8_t add8(uint8_t x,uint8_t y,int cy){uint16_t z=(uint16_t)x+y+cy; fa=((x&15)+(y&15)+cy)>15;fc=z>255;uint8_t r=z;setzsp(r);return r;}
static uint8_t sub8(uint8_t x,uint8_t y,int cy){int z=(int)x-(int)y-cy; fa=((x&15)-(y&15)-cy)<0;fc=z<0;uint8_t r=(uint8_t)z;setzsp(r);return r;}
static void alu(int op,uint8_t v){switch(op){case 0:A=add8(A,v,0);break;case 1:A=add8(A,v,fc);break;case 2:A=sub8(A,v,0);break;case 3:A=sub8(A,v,fc);break;case 4:A&=v;fc=0;fa=1;setzsp(A);break;case 5:A^=v;fc=fa=0;setzsp(A);break;case 6:A|=v;fc=fa=0;setzsp(A);break;case 7:{uint8_t old=A;sub8(old,v,0);A=old;break;}}}

static void fcb_name(uint16_t fcb,char out[13]){
 char n[9],e[4]; for(int i=0;i<8;i++){char c=mem[fcb+1+i]&0x7f;n[i]=(c==' '?' ':toupper((unsigned char)c));}n[8]=0;
 for(int i=0;i<3;i++){char c=mem[fcb+9+i]&0x7f;e[i]=(c==' '?' ':toupper((unsigned char)c));}e[3]=0;
 int ni=7;while(ni>=0&&n[ni]==' ')n[ni--]=0; int ei=2;while(ei>=0&&e[ei]==' ')e[ei--]=0;
 if(e[0])snprintf(out,13,"%s.%s",n,e);else snprintf(out,13,"%s",n);
}
static void hostpath(const char *name,char *out,size_t n){snprintf(out,n,"%s/%s",workdir,name);}
static int exists_name(const char *name,char actual[256]){DIR *d=opendir(workdir);if(!d)return 0;struct dirent *de;while((de=readdir(d))){if(!strcasecmp(de->d_name,name)){if(actual)strncpy(actual,de->d_name,255);closedir(d);return 1;}}closedir(d);return 0;}
static int wildcard_match(const char *pat,const char *name){char p8[12],n8[12]; memset(p8,' ',11);memset(n8,' ',11);p8[11]=n8[11]=0;const char *dot=strchr(pat,'.');int nl=dot?dot-pat:strlen(pat);if(nl>8)nl=8;for(int i=0;i<nl;i++)p8[i]=toupper((unsigned char)pat[i]);if(dot){dot++;for(int i=0;i<3&&dot[i];i++)p8[8+i]=toupper((unsigned char)dot[i]);}dot=strchr(name,'.');nl=dot?dot-name:strlen(name);if(nl>8)nl=8;for(int i=0;i<nl;i++)n8[i]=toupper((unsigned char)name[i]);if(dot){dot++;for(int i=0;i<3&&dot[i];i++)n8[8+i]=toupper((unsigned char)dot[i]);}for(int i=0;i<11;i++)if(p8[i]!='?'&&p8[i]!=n8[i])return 0;return 1;}
static uint32_t fcb_seqrec(uint16_t f){return (((uint32_t)(mem[f+14]&0x3f)*32u + (mem[f+12]&0x1f))*128u + mem[f+32]);}
static void fcb_inc(uint16_t f){if(++mem[f+32]==128){mem[f+32]=0;if(++mem[f+12]==32){mem[f+12]=0;mem[f+14]++;}}}
static void fill_dirent(uint16_t addr,const char *name){memset(&mem[addr],0,32);mem[addr]=current_user;char tmp[256];strncpy(tmp,name,sizeof(tmp)-1);tmp[sizeof(tmp)-1]=0;char *dot=strchr(tmp,'.');if(dot)*dot++=0;for(int i=0;i<8;i++)mem[addr+1+i]=(i<(int)strlen(tmp))?toupper((unsigned char)tmp[i]):' ';for(int i=0;i<3;i++)mem[addr+9+i]=(dot&&i<(int)strlen(dot))?toupper((unsigned char)dot[i]):' ';char act[256],path[4096];if(exists_name(name,act)){hostpath(act,path,sizeof(path));struct stat st;if(!stat(path,&st)){uint32_t rec=(st.st_size+127)/128;mem[addr+15]=rec>128?128:rec;}}}

static uint8_t bdos(){uint16_t f=DE();char fn[13],act[256],path[4096];switch(C){
 case 0: normal_exit=1; halted=1; return 0;
 case 1:{int ch=getchar();if(ch==EOF)ch=0x1a;putchar(ch);fflush(stdout);return ch;}
 case 2: putchar(E);fflush(stdout);return E;
 case 6: if(E==0xff)return 0;putchar(E);fflush(stdout);return E;
 case 9:{uint16_t p=DE();while(mem[p]!='$'){putchar(mem[p++]);}fflush(stdout);return '$';}
 case 10:return 0;
 case 11:return 0;
 case 12:return 0x31; // CP/M 3.1-ish
 case 13:return 0;
 case 14: current_drive=E; return 0;
 case 15: fcb_name(f,fn); if(exists_name(fn,act)){mem[f+12]=mem[f+14]=mem[f+32]=0;return 0;} return 0xff;
 case 16:return 0;
 case 17:{fcb_name(f,fn);search_n=search_i=0;DIR*d=opendir(workdir);if(d){struct dirent*de;while((de=readdir(d))&&search_n<1024){if(de->d_name[0]=='.')continue;if(wildcard_match(fn,de->d_name)){strncpy(search_names[search_n++],de->d_name,12);search_names[search_n-1][12]=0;}}closedir(d);} if(!search_n)return 0xff;fill_dirent(dma,search_names[search_i++]);return 0;}
 case 18: if(search_i>=search_n)return 0xff;fill_dirent(dma,search_names[search_i++]);return 0;
 case 19: fcb_name(f,fn); if(exists_name(fn,act)){hostpath(act,path,sizeof(path));unlink(path);return 0;} return 0xff;
 case 20:{fcb_name(f,fn);if(!exists_name(fn,act))return 1;hostpath(act,path,sizeof(path));FILE*fp0=fopen(path,"rb");if(!fp0)return 1;uint32_t r=fcb_seqrec(f);fseek(fp0,r*128u,SEEK_SET);size_t n=fread(&mem[dma],1,128,fp0);fclose(fp0);if(n==0)return 1;if(n<128)memset(&mem[dma+n],0x1a,128-n);fcb_inc(f);return 0;}
 case 21:{fcb_name(f,fn);if(!exists_name(fn,act))strncpy(act,fn,255);hostpath(act,path,sizeof(path));FILE*fp0=fopen(path,"r+b");if(!fp0)fp0=fopen(path,"w+b");if(!fp0)return 1;uint32_t r=fcb_seqrec(f);fseek(fp0,r*128u,SEEK_SET);fwrite(&mem[dma],1,128,fp0);fclose(fp0);fcb_inc(f);return 0;}
 case 22: fcb_name(f,fn);hostpath(fn,path,sizeof(path));{FILE*fp0=fopen(path,"wb");if(!fp0)return 0xff;fclose(fp0);}mem[f+12]=mem[f+14]=mem[f+32]=0;return 0;
 case 23:return 0xff;
 case 24:return 1u<<current_drive;
 case 25:return current_drive;
 case 26:dma=DE();return 0;
 case 31:return 0;
 case 32: if(E==0xff)return current_user; current_user=E&0x1f; return current_user;
 case 33:{fcb_name(f,fn);if(!exists_name(fn,act))return 1;hostpath(act,path,sizeof(path));FILE*fp0=fopen(path,"rb");if(!fp0)return 1;uint32_t r=mem[f+33]|((uint32_t)mem[f+34]<<8)|((uint32_t)mem[f+35]<<16);fseek(fp0,r*128u,SEEK_SET);size_t n=fread(&mem[dma],1,128,fp0);fclose(fp0);if(n==0)return 1;if(n<128)memset(&mem[dma+n],0x1a,128-n);return 0;}
 case 34: case 40:{fcb_name(f,fn);if(!exists_name(fn,act))strncpy(act,fn,255);hostpath(act,path,sizeof(path));FILE*fp0=fopen(path,"r+b");if(!fp0)fp0=fopen(path,"w+b");if(!fp0)return 1;uint32_t r=mem[f+33]|((uint32_t)mem[f+34]<<8)|((uint32_t)mem[f+35]<<16);fseek(fp0,r*128u,SEEK_SET);fwrite(&mem[dma],1,128,fp0);fclose(fp0);return 0;}
 case 35:{fcb_name(f,fn);if(!exists_name(fn,act))return 0xff;hostpath(act,path,sizeof(path));struct stat st;if(stat(path,&st))return 0xff;uint32_t r=(st.st_size+127)/128;mem[f+33]=r;mem[f+34]=r>>8;mem[f+35]=r>>16;return 0;}
 case 36:{uint32_t r=fcb_seqrec(f);mem[f+33]=r;mem[f+34]=r>>8;mem[f+35]=r>>16;return 0;}
 default: fprintf(stderr,"\nUnhandled BDOS %u DE=%04X PC(return)=%04X\n",C,DE(),rw(sp)); halted=1; return 0xff;
 }}

static uint8_t next8(){return mem[pc++];}static uint16_t next16(){uint16_t v=rw(pc);pc+=2;return v;}
static void step(){uint8_t op=next8();
 if((op&0xC0)==0x40){if(op==0x76){halted=1;return;}setr((op>>3)&7,getr(op&7));return;}
 if((op&0xC0)==0x80){alu((op>>3)&7,getr(op&7));return;}
 if((op&0xC7)==0x04){int r=(op>>3)&7;uint8_t x=getr(r),y=x+1;fa=((x&15)+1)>15;setzsp(y);setr(r,y);return;}
 if((op&0xC7)==0x05){int r=(op>>3)&7;uint8_t x=getr(r),y=x-1;fa=(x&15)==0;setzsp(y);setr(r,y);return;}
 if((op&0xC7)==0x06){setr((op>>3)&7,next8());return;}
 if((op&0xCF)==0x01){setrp((op>>4)&3,next16());return;}
 if((op&0xCF)==0x03){int rp=(op>>4)&3;setrp(rp,getrp(rp)+1);return;}
 if((op&0xCF)==0x0B){int rp=(op>>4)&3;setrp(rp,getrp(rp)-1);return;}
 if((op&0xCF)==0x09){uint32_t z=(uint32_t)HL()+getrp((op>>4)&3);fc=(z>0xffff);setHL(z);return;}
 if((op&0xC7)==0xC0){if(cond((op>>3)&7))pc=pop();return;}
 if((op&0xCF)==0xC1){uint16_t v=pop();if(((op>>4)&3)==3){A=v>>8;flags_unpack(v&0xff);}else setrp((op>>4)&3,v);return;}
 if((op&0xC7)==0xC2){uint16_t a=next16();if(cond((op>>3)&7))pc=a;return;}
 if((op&0xC7)==0xC4){uint16_t a=next16();if(cond((op>>3)&7)){push(pc);pc=a;}return;}
 if((op&0xCF)==0xC5){uint16_t v;if(((op>>4)&3)==3)v=((uint16_t)A<<8)|flags_pack();else v=getrp((op>>4)&3);push(v);return;}
 if((op&0xC7)==0xC6){alu((op>>3)&7,next8());return;}
 if((op&0xC7)==0xC7){push(pc);pc=op&0x38;return;}
 switch(op){
 case 0x00:case 0x08:case 0x10:case 0x18:case 0x20:case 0x28:case 0x30:case 0x38:return;
 case 0x02:mem[BC()]=A;return;case 0x12:mem[DE()]=A;return;case 0x0a:A=mem[BC()];return;case 0x1a:A=mem[DE()];return;
 case 0x07:{int c=A>>7;A=(A<<1)|c;fc=c;return;}case 0x0f:{int c=A&1;A=(A>>1)|(c<<7);fc=c;return;}case 0x17:{int c=A>>7;A=(A<<1)|fc;fc=c;return;}case 0x1f:{int c=A&1;A=(A>>1)|(fc<<7);fc=c;return;}
 case 0x22:{uint16_t a=next16();ww(a,HL());return;}case 0x2a:{uint16_t a=next16();setHL(rw(a));return;}case 0x32:{uint16_t a=next16();mem[a]=A;return;}case 0x3a:{uint16_t a=next16();A=mem[a];return;}
 case 0x27:{uint8_t corr=0;int c=fc;if((A&0xf)>9||fa)corr|=6;if(A>0x99||fc){corr|=0x60;c=1;}A=add8(A,corr,0);fc=c;return;}
 case 0x2f:A=~A;return;case 0x37:fc=1;return;case 0x3f:fc=!fc;return;
 case 0xc3:pc=next16();return;case 0xc9:pc=pop();return;case 0xcd:{uint16_t a=next16();push(pc);pc=a;return;}
 case 0xd3:{uint8_t p=next8();(void)p;return;}case 0xdb:{uint8_t p=next8();(void)p;A=0;return;}
 case 0xe3:{uint16_t t=rw(sp);ww(sp,HL());setHL(t);return;}case 0xe9:pc=HL();return;case 0xeb:{uint16_t t=DE();setDE(HL());setHL(t);return;}
 case 0xf3:return;case 0xf9:sp=HL();return;case 0xfb:return;
 case 0xcb:pc=next16();return; case 0xd9:pc=pop();return; case 0xdd:case 0xed:case 0xfd: fprintf(stderr,"Z80 prefix %02X at %04X unsupported\n",op,(uint16_t)(pc-1));halted=1;return;
 default:fprintf(stderr,"Unknown opcode %02X at %04X\n",op,(uint16_t)(pc-1));halted=1;return; }
}

static void init_fcb(uint16_t a,const char*arg){memset(&mem[a],0,36);const char*p=arg;if(isalpha((unsigned char)p[0])&&p[1]==':'){mem[a]=toupper(p[0])-'A'+1;p+=2;}char name[9]={0},ext[4]={0};const char*dot=strchr(p,'.');int n=dot?dot-p:strlen(p);if(n>8)n=8;for(int i=0;i<n;i++)name[i]=toupper((unsigned char)p[i]);if(dot){dot++;for(int i=0;i<3&&dot[i]&&dot[i]!='[';i++)ext[i]=toupper((unsigned char)dot[i]);}for(int i=0;i<8;i++)mem[a+1+i]=name[i]?name[i]:' ';for(int i=0;i<3;i++)mem[a+9+i]=ext[i]?ext[i]:' ';}
int main(int argc,char**argv){if(argc<2){fprintf(stderr,"usage: cpmrun PROG.COM [args...]\n");return 2;}char *slash=strrchr(argv[1],'/');char progpath[4096];strncpy(progpath,argv[1],sizeof(progpath)-1);if(slash){size_t n=slash-argv[1];memcpy(workdir,argv[1],n);workdir[n]=0;}else strcpy(workdir,".");FILE*f=fopen(progpath,"rb");if(!f){perror(progpath);return 2;}memset(mem,0,65536);size_t n=fread(mem+0x100,1,0xef00,f);fclose(f);mem[0]=0xc3;mem[1]=0;mem[2]=0;mem[5]=0xc3;mem[6]=0;mem[7]=0xf0; // top TPA hint
 char tail[128]="";if(argc>2)strcat(tail," ");for(int i=2;i<argc;i++){if(i>2)strcat(tail," ");strcat(tail,argv[i]);}size_t tl=strlen(tail);if(tl>126)tl=126;mem[0x80]=tl;memcpy(&mem[0x81],tail,tl);mem[0x81+tl]=0; if(argc>2)init_fcb(0x5c,argv[2]);if(argc>3)init_fcb(0x6c,argv[3]);
 pc=0x100;sp=0xeffe;unsigned long long steps=0,maxsteps=500000000ULL;while(!halted&&steps++<maxsteps){if(pc==0){break;}if(pc==5){uint8_t r=bdos();A=L=r;pc=pop();continue;}step();}if(steps>=maxsteps){fprintf(stderr,"timeout steps=%llu pc=%04x\n",steps,pc);return 3;}fprintf(stderr,"\n[cpmrun steps=%llu pc=%04x]\n",steps,pc);return (halted && !normal_exit)?1:0;}
