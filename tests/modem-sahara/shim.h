/* SPDX-License-Identifier: MIT */
#ifndef SAHARA_TEST_SHIM_H
#define SAHARA_TEST_SHIM_H
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
typedef uint8_t u8;
typedef uint32_t u32;
typedef uint64_t u64;
typedef uint32_t __le32;
typedef int spinlock_t;
typedef struct { int n; } atomic_t;
struct completion { bool done; };
struct work_struct { int unused; };
struct device { void *data; };
struct mhi_controller { struct device *cntrl_dev; };
struct mhi_device { struct device dev; struct mhi_controller *mhi_cntrl; };
struct pci_dev { struct device dev; unsigned int vendor, device; };
struct mhi_device_id { const char *chan; };
struct mhi_result { int transaction_status; size_t bytes_xferd; };
struct firmware { const u8 *data; size_t size; };
struct mhi_driver {
 const struct mhi_device_id *id_table;
 int (*probe)(struct mhi_device *, const struct mhi_device_id *);
 void (*remove)(struct mhi_device *);
 void (*ul_xfer_cb)(struct mhi_device *, struct mhi_result *);
 void (*dl_xfer_cb)(struct mhi_device *, struct mhi_result *);
 struct { const char *name; } driver;
};
#define SZ_1M (1024U * 1024U)
#define SZ_64M (64U * SZ_1M)
#define U32_MAX UINT32_MAX
#define PCI_VENDOR_ID_QCOM 0x17cb
#define GFP_KERNEL 0
#define DMA_TO_DEVICE 1
#define DMA_FROM_DEVICE 2
#define MHI_EOT 1
#define MHI_CHAIN 2
#define MODULE_DEVICE_TABLE(a,b)
#define MODULE_DESCRIPTION(a)
#define MODULE_LICENSE(a)
#define module_mhi_driver(a)
#define container_of(p,t,m) ((t *)((char *)(p) - offsetof(t,m)))
#define min_t(t,a,b) ((t)(a) < (t)(b) ? (t)(a) : (t)(b))
#define DIV_ROUND_UP(a,b) (((a)+(b)-1)/(b))
#define ARRAY_SIZE(a) (sizeof(a)/sizeof((a)[0]))
#define cpu_to_le32(a) ((uint32_t)(a))
#define le32_to_cpu(a) ((uint32_t)(a))
#define READ_ONCE(a) (a)
#define spin_lock_irqsave(a,b) ((void)(a),(void)(b))
#define spin_unlock_irqrestore(a,b) ((void)(a),(void)(b))
#define spin_lock_init(a) (*(a)=0)
#define INIT_WORK(a,b) ((void)(a))
#define dev_err(...) ((void)0)
static inline void init_completion(struct completion *c) { c->done=false; }
static inline void reinit_completion(struct completion *c) { c->done=false; }
static inline void complete(struct completion *c) { c->done=true; }
static inline void complete_all(struct completion *c) { c->done=true; }
static inline int wait_for_completion_timeout(struct completion *c, int t) { return c->done; }
static inline int msecs_to_jiffies(int t) { return t; }
static inline void atomic_set(atomic_t *a, int n) { a->n=n; }
static inline int atomic_read(atomic_t *a) { return a->n; }
static inline int atomic_dec_and_test(atomic_t *a) { return --a->n == 0; }
static inline void *dev_get_drvdata(struct device *d) { return d->data; }
static inline void dev_set_drvdata(struct device *d, void *v) { d->data=v; }
static inline void *devm_kzalloc(struct device *d,size_t n,int f) { return calloc(1,n); }
static inline void *devm_kmalloc(struct device *d,size_t n,int f) { return malloc(n); }
static inline bool dev_is_pci(struct device *d) { return true; }
static inline struct pci_dev *to_pci_dev(struct device *d) { return (void *)d; }
static inline bool device_property_read_bool(struct device *d,const char *p) { return true; }
static inline int mhi_prepare_for_transfer(struct mhi_device *m) { return 0; }
static inline void mhi_unprepare_from_transfer(struct mhi_device *m) {}
static inline void cancel_work_sync(struct work_struct *w) {}
static inline void schedule_work(struct work_struct *w) {}
static inline void release_firmware(const struct firmware *f) {}
static int request_firmware_direct(const struct firmware **,const char *,struct device *);
static int mhi_get_free_desc_count(struct mhi_device *,int);
static int mhi_queue_buf(struct mhi_device *,int,void *,size_t,int);
#endif
