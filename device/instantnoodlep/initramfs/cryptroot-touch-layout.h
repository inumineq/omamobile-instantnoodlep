/* SPDX-License-Identifier: MIT */
#ifndef OMAMOBILE_CRYPTROOT_TOUCH_LAYOUT_H
#define OMAMOBILE_CRYPTROOT_TOUCH_LAYOUT_H

#define TOUCH_LAYOUT_ROW_COUNT 4
#define TOUCH_LAYOUT_TOP(height) ((height) * 3 / 8)
#define TOUCH_LAYOUT_ROW_HEIGHT(height) ((height) / 10)

static const char *const touch_layout_rows[TOUCH_LAYOUT_ROW_COUNT] = {
    "1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"
};

static inline int touch_layout_length(const char *text) {
    int length = 0;
    while (text[length]) length++;
    return length;
}

enum touch_key_action {
    TOUCH_KEY_NONE,
    TOUCH_KEY_CHARACTER,
    TOUCH_KEY_SHIFT,
    TOUCH_KEY_BACKSPACE,
    TOUCH_KEY_SPACE,
    TOUCH_KEY_ENTER
};

struct touch_key {
    enum touch_key_action action;
    char character;
};

static inline struct touch_key touch_layout_hit(int x, int y, int width,
                                                 int height, int shifted) {
    struct touch_key key = { TOUCH_KEY_NONE, 0 };
    if (width <= 0 || height <= 0 || x < 0 || x >= width || y < 0 || y >= height)
        return key;

    int top = TOUCH_LAYOUT_TOP(height);
    int row_height = TOUCH_LAYOUT_ROW_HEIGHT(height);
    if (row_height <= 0) return key;
    for (int row = 0; row < TOUCH_LAYOUT_ROW_COUNT; row++) {
        if (y < top + row * row_height || y >= top + (row + 1) * row_height)
            continue;
        int count = touch_layout_length(touch_layout_rows[row]);
        int cell_width = width / count;
        if (cell_width <= 0) return key;
        int col = x / cell_width;
        if (col >= count) col = count - 1;
        key.action = TOUCH_KEY_CHARACTER;
        key.character = touch_layout_rows[row][col];
        if (shifted && key.character >= 'a' && key.character <= 'z')
            key.character = (char)(key.character - 'a' + 'A');
        return key;
    }

    if (y >= top + TOUCH_LAYOUT_ROW_COUNT * row_height &&
        y < top + (TOUCH_LAYOUT_ROW_COUNT + 1) * row_height) {
        if (x < width / 5) key.action = TOUCH_KEY_SHIFT;
        else if (x < width * 2 / 5) key.action = TOUCH_KEY_BACKSPACE;
        else if (x < width * 3 / 5) key.action = TOUCH_KEY_SPACE;
        else key.action = TOUCH_KEY_ENTER;
    }
    return key;
}

#endif
