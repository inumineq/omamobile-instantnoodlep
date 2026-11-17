/* SPDX-License-Identifier: MIT */
#include "shim.h"
#include LOADER_SOURCE

static unsigned int lookups, queues, eots, chains, fail_at;
static int slots = 3, completion_status, firmware_error;
static bool suppress_completion, check_payload;
static size_t sent, expected_offset;
static u8 payload[3 * SZ_1M];
static struct firmware firmware = { .data=payload, .size=sizeof(payload) };

static int request_firmware_direct(const struct firmware **f,const char *n,struct device *d)
{
 lookups++;
 if (firmware_error) return firmware_error;
 *f=&firmware;
 return 0;
}
static int mhi_get_free_desc_count(struct mhi_device *m,int dir) { return slots; }
static int mhi_queue_buf(struct mhi_device *m,int dir,void *data,size_t len,int flags)
{
 struct mhi_result r = { .transaction_status=completion_status };
 assert(dir == DMA_TO_DEVICE);
 assert(len > 0 && len <= SAHARA_MTU);
 queues++;
 if (fail_at && queues == fail_at) return -EIO;
 if (check_payload) {
  assert(expected_offset + sent + len <= sizeof(payload));
  assert(!memcmp(data,payload+expected_offset+sent,len));
 }
 sent+=len;
 if (flags == MHI_EOT) eots++; else { assert(flags == MHI_CHAIN); chains++; }
 if (!suppress_completion) sahara_ul(m,&r);
 return 0;
}

static struct sahara session;
static struct mhi_device device;
static __le32 packet[12];
static void reset_session(void)
{
 memset(&session,0,sizeof(session));
 memset(packet,0,sizeof(packet));
 session.mhi=&device;
 session.rx=packet;
 session.image=SAHARA_NO_IMAGE;
 device.dev.data=&session;
 for (int i=0;i<SAHARA_BATCH;i++) {
  static u8 buffers[SAHARA_BATCH][SAHARA_MTU];
  session.tx[i]=buffers[i];
 }
 lookups=queues=eots=chains=fail_at=0;
 slots=3;
 completion_status=firmware_error=0;
 firmware.size=sizeof(payload);
 suppress_completion=check_payload=false;
 sent=expected_offset=0;
}
static void command(u32 cmd, u32 len)
{
 memset(packet,0,sizeof(packet));
 packet[0]=cmd; packet[1]=len;
 session.rx_len=len;
}
static void hello(void)
{
 command(SAHARA_HELLO,48);
 packet[2]=2; packet[3]=2; packet[4]=48;
}
static void read_image(u32 image,u32 offset,u32 len)
{
 session.state=SAHARA_READY;
 command(SAHARA_READ_DATA,20);
 packet[2]=image; packet[3]=offset; packet[4]=len;
}
int main(void)
{
 for (size_t i=0;i<sizeof(payload);i++) payload[i]=(i*13+i/256)&255;
 for (int n=0;n<48;n++) {
  reset_session(); hello(); session.rx_len=n;
  assert(sahara_command(&session) == -EPROTO);
  assert(!queues && !lookups);
 }
 for (int mode=0;mode<4;mode++) {
  reset_session(); hello(); packet[5]=mode;
  assert(sahara_command(&session) == (mode>1 ? -EPROTO : 0));
 }
 reset_session(); hello(); packet[3]=3; assert(sahara_command(&session)==-EPROTO);
 reset_session(); hello(); packet[4]=47; assert(sahara_command(&session)==-EPROTO);
 for (u32 id=0;id<60;id++) {
  if (id<ARRAY_SIZE(sahara_images) && sahara_images[id]) continue;
  reset_session(); read_image(id,0,1);
  assert(sahara_command(&session)==-EACCES);
  assert(!lookups && !queues);
 }
 reset_session(); read_image(6,0,1); firmware_error=-ENOENT;
 assert(sahara_command(&session)==-ENOENT && !queues);
 reset_session(); read_image(6,0,1); firmware.size=SAHARA_MAX_IMAGE+1;
 assert(sahara_command(&session)==-EFBIG && !queues);
 reset_session(); command(SAHARA_END_IMAGE,16); session.state=SAHARA_READY;
 assert(sahara_command(&session)==-EPROTO && !queues);
 reset_session(); read_image(6,0,1); assert(!sahara_command(&session));
 command(SAHARA_END_IMAGE,16); packet[2]=8;
 assert(sahara_command(&session)==-EPROTO);
 packet[2]=6; packet[3]=1; assert(sahara_command(&session)==-EIO);
 reset_session(); command(SAHARA_DONE_RESP,12); packet[2]=1;
 assert(sahara_command(&session)==-EPROTO && !queues);
 session.state=SAHARA_WAIT_DONE; packet[2]=2;
 assert(sahara_command(&session)==-EPROTO && !queues);
 reset_session(); read_image(6,U32_MAX,32);
 assert(sahara_command(&session)==-EINVAL && !queues);
 reset_session(); read_image(6,sizeof(payload)-4,U32_MAX);
 assert(sahara_command(&session)==-EINVAL && !queues);
 reset_session(); read_image(6,0,0); assert(sahara_command(&session)==-EINVAL);
 reset_session(); read_image(6,0,16); session.served=SAHARA_MAX_SERVED-8;
 assert(sahara_command(&session)==-EFBIG && !queues);
 reset_session(); read_image(6,0,1); session.image=8;
 assert(sahara_command(&session)==-EPROTO && !lookups);
 reset_session(); read_image(6,17,SZ_1M+29);
 check_payload=true; expected_offset=17;
 assert(!sahara_command(&session));
 assert(sent==SZ_1M+29 && queues==17 && chains==11 && eots==6);
 check_payload=false;
 command(SAHARA_END_IMAGE,16); packet[2]=6;
 assert(!sahara_command(&session) && session.state==SAHARA_WAIT_DONE && !session.fw);
 command(SAHARA_DONE_RESP,12); packet[2]=0;
 assert(!sahara_command(&session) && session.state==SAHARA_WAIT_HELLO);
 hello(); assert(!sahara_command(&session));
 read_image(8,0,1); assert(!sahara_command(&session));
 command(SAHARA_END_IMAGE,16); packet[2]=8; assert(!sahara_command(&session));
 command(SAHARA_DONE_RESP,12); packet[2]=1; assert(sahara_command(&session)==1);
 for (int cmd=7;cmd<=20;cmd++) {
  reset_session(); command(cmd,8);
  assert(sahara_command(&session)==-EOPNOTSUPP && !queues && !lookups);
 }
 reset_session(); read_image(6,0,1); slots=0;
 assert(sahara_command(&session)==-ENOSPC && !queues);
 reset_session(); read_image(6,0,SAHARA_MTU*4); fail_at=2;
 assert(sahara_command(&session)==-EIO && queues==2);
 reset_session(); read_image(6,0,1); completion_status=-EIO;
 assert(sahara_command(&session)==-EIO);
 reset_session(); read_image(6,0,1); suppress_completion=true;
 assert(sahara_command(&session)==-ETIMEDOUT);
 reset_session(); read_image(6,0,1); session.stopping=true;
 assert(sahara_command(&session)==-ESHUTDOWN);
 reset_session(); hello(); session.commands=SAHARA_MAX_COMMANDS;
 assert(sahara_command(&session)==-EPROTO && !queues);
 puts("PASS: actual Sahara parser/allowlist, bounds, batching, ring/queue/completion failures");
 return 0;
}
