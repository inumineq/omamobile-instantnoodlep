/* SPDX-License-Identifier: MIT */
#include "../device/instantnoodlep/initramfs/cryptroot-touch-layout.h"

static long syscall3(long number, long arg1, long arg2, long arg3) {
    register long result __asm__("rax") = number;
    register long first __asm__("rdi") = arg1;
    register long second __asm__("rsi") = arg2;
    register long third __asm__("rdx") = arg3;
    __asm__ volatile("syscall" : "+a"(result) : "D"(first), "S"(second), "d"(third)
                     : "rcx", "r11", "memory");
    return result;
}

static int text_length(const char *text) {
    int length = 0;
    while (text[length]) length++;
    return length;
}

static void expect(int x, int y, int width, int height, int shifted,
                   enum touch_key_action action, char character,
                   const char *name) {
    struct touch_key got = touch_layout_hit(x, y, width, height, shifted);
    if (got.action != action || got.character != character) {
        syscall3(1, 2, (long)name, text_length(name));
        syscall3(1, 2, (long)" failed\n", 8);
        syscall3(60, 1, 0, 0);
    }
}

__attribute__((noreturn)) void _start(void) {
    const int w = 640, h = 480;
    int top = TOUCH_LAYOUT_TOP(h), row = TOUCH_LAYOUT_ROW_HEIGHT(h);
    expect(32, top + row / 2, w, h, 0, TOUCH_KEY_CHARACTER, '1', "first digit");
    expect(608, top + row / 2, w, h, 0, TOUCH_KEY_CHARACTER, '0', "last digit");
    expect(32, top + row + row / 2, w, h, 0, TOUCH_KEY_CHARACTER, 'q', "first letter");
    expect(35, top + 2 * row + row / 2, w, h, 0, TOUCH_KEY_CHARACTER, 'a', "home row");
    expect(409, top + 3 * row + row / 2, w, h, 0, TOUCH_KEY_CHARACTER, 'b', "bottom row");
    expect(35, top + 2 * row + row / 2, w, h, 1, TOUCH_KEY_CHARACTER, 'A', "shifted letter");
    expect(32, top + 4 * row + row / 2, w, h, 0, TOUCH_KEY_SHIFT, 0, "shift action");
    expect(192, top + 4 * row + row / 2, w, h, 0, TOUCH_KEY_BACKSPACE, 0, "backspace action");
    expect(320, top + 4 * row + row / 2, w, h, 0, TOUCH_KEY_SPACE, 0, "space action");
    expect(512, top + 4 * row + row / 2, w, h, 0, TOUCH_KEY_ENTER, 0, "enter action");
    expect(0, top + row, w, h, 0, TOUCH_KEY_CHARACTER, 'q', "row boundary");
    expect(-1, 10, w, h, 0, TOUCH_KEY_NONE, 0, "outside left edge");
    expect(w, 10, w, h, 0, TOUCH_KEY_NONE, 0, "outside right edge");
    expect(10, h, w, h, 0, TOUCH_KEY_NONE, 0, "outside bottom edge");
    static const char passed[] = "PASS - touch keypad layout and hit testing\n";
    syscall3(1, 1, (long)passed, text_length(passed));
    syscall3(60, 0, 0, 0);
    __builtin_unreachable();
}
