/* SPDX-License-Identifier: MIT */
/* Minimal framebuffer/evdev LUKS2 prompt; static libc only. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <linux/input.h>
#include <linux/limits.h>
#include <stdint.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include "cryptroot-touch-layout.h"

#define MAX_SECRET 256
#define COLOR_BG 0x101820u
#define COLOR_KEY 0x24546au
#define COLOR_ENTER 0x26734du
#define COLOR_INK 0xe8f0f4u

static uint32_t *pixels;
static struct fb_var_screeninfo var;
static struct fb_fix_screeninfo fix;
static int fbfd = -1;
static int width, height, stride;
static char secret[MAX_SECRET];
static size_t secret_len;
static int shifted;

static uint32_t rgb_pixel(uint32_t rgb);

static void rect(int x, int y, int w, int h, uint32_t rgb) {
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > width) w = width - x;
    if (y + h > height) h = height - y;
    if (w <= 0 || h <= 0) return;
    for (int row = y; row < y + h; row++)
        for (int col = x; col < x + w; col++)
            pixels[row * stride + col] = rgb_pixel(rgb);
}

static uint32_t rgb_pixel(uint32_t rgb) {
    uint32_t r = (rgb >> 16) & 255, g = (rgb >> 8) & 255, b = rgb & 255;
    uint32_t out = 0;
    out |= ((r >> (8 - var.red.length)) << var.red.offset);
    out |= ((g >> (8 - var.green.length)) << var.green.offset);
    out |= ((b >> (8 - var.blue.length)) << var.blue.offset);
    if (var.transp.length) out |= (((1u << var.transp.length) - 1) << var.transp.offset);
    return out;
}

/* Compact 5x7 glyphs for the keyboard labels and prompt. */
static const uint8_t font[37][5] = {
 {0x7e,0x11,0x11,0x11,0x7e},{0x7f,0x49,0x49,0x49,0x36},
 {0x3e,0x41,0x41,0x41,0x22},{0x7f,0x41,0x41,0x22,0x1c},
 {0x7f,0x49,0x49,0x49,0x41},{0x7f,0x09,0x09,0x09,0x01},
 {0x3e,0x41,0x49,0x49,0x7a},{0x7f,0x08,0x08,0x08,0x7f},
 {0x00,0x41,0x7f,0x41,0x00},{0x20,0x40,0x41,0x3f,0x01},
 {0x7f,0x08,0x14,0x22,0x41},{0x7f,0x40,0x40,0x40,0x40},
 {0x7f,0x02,0x0c,0x02,0x7f},{0x7f,0x04,0x08,0x10,0x7f},
 {0x3e,0x41,0x41,0x41,0x3e},{0x7f,0x09,0x09,0x09,0x06},
 {0x3e,0x41,0x51,0x21,0x5e},{0x7f,0x09,0x19,0x29,0x46},
 {0x46,0x49,0x49,0x49,0x31},{0x01,0x01,0x7f,0x01,0x01},
 {0x3f,0x40,0x40,0x40,0x3f},{0x1f,0x20,0x40,0x20,0x1f},
 {0x3f,0x40,0x38,0x40,0x3f},{0x63,0x14,0x08,0x14,0x63},
 {0x07,0x08,0x70,0x08,0x07},{0x61,0x51,0x49,0x45,0x43},
 {0x3e,0x51,0x49,0x45,0x3e},{0x00,0x42,0x7f,0x40,0x00},
 {0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4b,0x31},
 {0x18,0x14,0x12,0x7f,0x10},{0x27,0x45,0x45,0x45,0x39},
 {0x3c,0x4a,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
 {0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1e},
 {0x00,0x00,0x5f,0x00,0x00}
};

static int glyph_index(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= '0' && c <= '9') return 26 + c - '0';
    if (c == '-') return 36;
    return -1;
}

static void text(int x, int y, const char *s, int scale) {
    for (; *s; s++, x += 6 * scale) {
        int idx = glyph_index(*s);
        if (idx < 0) continue;
        for (int col = 0; col < 5; col++)
            for (int row = 0; row < 7; row++)
                if (font[idx][col] & (1u << row))
                    rect(x + col * scale, y + row * scale, scale, scale, COLOR_INK);
    }
}

static void key(int x, int y, int w, int h, const char *label, uint32_t color) {
    rect(x + 2, y + 2, w - 4, h - 4, color);
    int scale = w / ((int)strlen(label) * 6 + 2);
    if (scale < 1) scale = 1;
    if (scale > h / 10) scale = h / 10;
    if (scale < 1) scale = 1;
    int tx = x + (w - ((int)strlen(label) * 6 - 1) * scale) / 2;
    int ty = y + (h - 7 * scale) / 2;
    text(tx, ty, label, scale);
}

static int draw(void) {
    rect(0, 0, width, height, COLOR_BG);
    text(width / 24, height / 24, "UNLOCK ENCRYPTED ROOT", width / 150 > 0 ? width / 150 : 1);
    int box_y = height / 8, box_h = height / 9;
    key(width / 20, box_y, width * 9 / 10, box_h, "PASSPHRASE", COLOR_KEY);
    for (size_t i = 0; i < secret_len && i < 30; i++)
        rect(width / 16 + (int)i * width / 36, box_y + box_h / 2,
             width / 80, width / 80, COLOR_INK);
    int top = TOUCH_LAYOUT_TOP(height), kh = TOUCH_LAYOUT_ROW_HEIGHT(height);
    for (int r = 0; r < TOUCH_LAYOUT_ROW_COUNT; r++) {
        int n = (int)strlen(touch_layout_rows[r]), cell = width / n;
        for (int c = 0; c < n; c++) {
            char label[2] = {touch_layout_rows[r][c], 0};
            if (shifted) label[0] = (char)(label[0] - 'a' + 'A');
            key(c * cell, top + r * kh, cell, kh, label, COLOR_KEY);
        }
    }
    int y = top + 4 * kh;
    int widths[] = {width / 5, width / 5, width / 5, width * 2 / 5};
    int xs[] = {0, width / 5, width * 2 / 5, width * 3 / 5};
    key(xs[0], y, widths[0], kh, "SHIFT", COLOR_KEY);
    key(xs[1], y, widths[1], kh, "BKSP", COLOR_KEY);
    key(xs[2], y, widths[2], kh, "SPACE", COLOR_KEY);
    key(xs[3], y, widths[3], kh, "ENTER", COLOR_ENTER);
    return msync(pixels, (size_t)fix.smem_len, MS_SYNC);
}

static int find_touch(int *fd, struct input_absinfo *ax, struct input_absinfo *ay) {
    char path[PATH_MAX], name[256];
    unsigned long key_bits[(KEY_MAX + sizeof(unsigned long) * 8) /
                           (sizeof(unsigned long) * 8)];
    for (int i = 0; i < 32; i++) {
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int f = open(path, O_RDONLY | O_NONBLOCK);
        if (f < 0) continue;
        memset(name, 0, sizeof(name));
        ioctl(f, EVIOCGNAME(sizeof(name)), name);
        memset(key_bits, 0, sizeof(key_bits));
        if (ioctl(f, EVIOCGBIT(EV_KEY, sizeof(key_bits)), key_bits) < 0 ||
            (!(key_bits[BTN_TOUCH / (sizeof(unsigned long) * 8)] &
              (1ul << (BTN_TOUCH % (sizeof(unsigned long) * 8)))) &&
             !(key_bits[BTN_LEFT / (sizeof(unsigned long) * 8)] &
               (1ul << (BTN_LEFT % (sizeof(unsigned long) * 8)))))) {
            close(f);
            continue;
        }
        if ((ioctl(f, EVIOCGABS(ABS_X), ax) == 0 || ioctl(f, EVIOCGABS(ABS_MT_POSITION_X), ax) == 0) &&
            (ioctl(f, EVIOCGABS(ABS_Y), ay) == 0 || ioctl(f, EVIOCGABS(ABS_MT_POSITION_Y), ay) == 0)) {
            *fd = f;
            return 0;
        }
        close(f);
    }
    return -1;
}

static int unlock_disk(const char *device, const char *mapper) {
    int pipefd[2];
    if (pipe(pipefd) < 0) return -1;
    pid_t pid = fork();
    if (pid < 0) { close(pipefd[0]); close(pipefd[1]); return -1; }
    if (pid == 0) {
        dup2(pipefd[0], STDIN_FILENO);
        close(pipefd[0]); close(pipefd[1]);
        execlp("cryptsetup", "cryptsetup", "open", "--type", "luks2",
               "--key-file=-", device, mapper, (char *)NULL);
        _exit(127);
    }
    close(pipefd[0]);
    size_t off = 0;
    while (off < secret_len) {
        ssize_t n = write(pipefd[1], secret + off, secret_len - off);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) break;
        off += (size_t)n;
    }
    /* EOF delimits the key file; don't append a terminal newline to the secret. */
    close(pipefd[1]);
    memset(secret, 0, sizeof(secret)); secret_len = 0;
    int status = 0;
    pid_t waited;
    do { waited = waitpid(pid, &status, 0); } while (waited < 0 && errno == EINTR);
    if (waited != pid) return 1;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}

static int append(char c) {
    if (secret_len + 1 >= sizeof(secret)) return -1;
    secret[secret_len++] = c;
    return 0;
}

static int hit(int x, int y, const char *device, const char *mapper) {
    struct touch_key key = touch_layout_hit(x, y, width, height, shifted);
    switch (key.action) {
    case TOUCH_KEY_CHARACTER:
        append(key.character); shifted = 0; return 0;
    case TOUCH_KEY_SHIFT:
        shifted = !shifted; return 0;
    case TOUCH_KEY_BACKSPACE:
        if (secret_len) secret[--secret_len] = 0;
        return 0;
    case TOUCH_KEY_SPACE:
        append(' '); return 0;
    case TOUCH_KEY_ENTER: {
        int status = unlock_disk(device, mapper);
        if (status == 0) { puts("TOUCH_UNLOCK_PASS"); return 1; }
        puts("TOUCH_UNLOCK_RETRY");
        return 0;
    }
    default:
        return 0;
    }
}

static int scale_abs(int value, struct input_absinfo *range, int extent) {
    if (range->maximum <= range->minimum) return 0;
    int64_t scaled = (int64_t)(value - range->minimum) * extent /
                     (range->maximum - range->minimum);
    if (scaled < 0) return 0;
    if (scaled >= extent) return extent - 1;
    return (int)scaled;
}

int main(int argc, char **argv) {
    signal(SIGPIPE, SIG_IGN);
    if (argc != 3) { fprintf(stderr, "usage: cryptroot-touch-unlock DEVICE MAPPER\n"); return 2; }
    fbfd = open("/dev/fb0", O_RDWR);
    if (fbfd < 0 || ioctl(fbfd, FBIOGET_VSCREENINFO, &var) < 0 ||
        ioctl(fbfd, FBIOGET_FSCREENINFO, &fix) < 0 || var.bits_per_pixel != 32) {
        fprintf(stderr, "touch unlock: 32-bit /dev/fb0 required\n"); return 1;
    }
    width = (int)var.xres; height = (int)var.yres; stride = (int)(fix.line_length / 4);
    pixels = mmap(NULL, fix.smem_len, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
    if (pixels == MAP_FAILED) { perror("mmap framebuffer"); return 1; }
    struct input_absinfo ax, ay;
    int input = -1;
    for (int i = 0; i < 100 && find_touch(&input, &ax, &ay) < 0; i++) usleep(100000);
    if (input < 0) { fprintf(stderr, "touch unlock: no absolute input device\n"); return 1; }
    draw();
    printf("TOUCH_UNLOCK_READY %d %d\n", width, height); fflush(stdout);
    int x = 0, y = 0, down = 0;
    struct input_event ev;
    for (;;) {
        ssize_t n = read(input, &ev, sizeof(ev));
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) { usleep(10000); continue; }
        if (n != sizeof(ev)) continue;
        if (ev.type == EV_ABS) {
            if (ev.code == ABS_X || ev.code == ABS_MT_POSITION_X) x = scale_abs(ev.value, &ax, width);
            if (ev.code == ABS_Y || ev.code == ABS_MT_POSITION_Y) y = scale_abs(ev.value, &ay, height);
        } else if (ev.type == EV_KEY && (ev.code == BTN_TOUCH || ev.code == BTN_LEFT)) {
            if (ev.value == 1) down = 1;
            if (ev.value == 0 && down) {
                down = 0;
                if (hit(x, y, argv[1], argv[2])) return 0;
                draw();
            }
        }
    }
}
