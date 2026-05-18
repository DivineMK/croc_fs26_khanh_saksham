#include "vga.h"
#include "uart.h"
#include "util.h"
#include "font_8x8.h"

void font_init(void) {
    for (int i = 0; i < 96; i++) {
        const uint8_t *ch = fontdata_8x8[i];
        uint32_t hi = ((uint32_t)ch[0] << 24) | ((uint32_t)ch[1] << 16) | ((uint32_t)ch[2] << 8) | (uint32_t)ch[3];
        uint32_t lo = ((uint32_t)ch[4] << 24) | ((uint32_t)ch[5] << 16) | ((uint32_t)ch[6] << 8) | (uint32_t)ch[7];
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i)     = lo;
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i + 4) = hi;
    }
}

void vga_init(void) {
    font_init();
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET)               = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_TB_ADDR_OFFSET)          = VGA_TB_BASE_ADDR;
    *reg32(VGA_REG_BASE_ADDR, VGA_CLK_DIV_OFFSET)          = 2;
    *reg32(VGA_REG_BASE_ADDR, VGA_HSYNC_POL_OFFSET)        = 1;
    *reg32(VGA_REG_BASE_ADDR, VGA_VSYNC_POL_OFFSET)        = 1;
    *reg32(VGA_REG_BASE_ADDR, VGA_LINE_WIDTH_OFFSET)       = VGA_COLS;
    *reg32(VGA_REG_BASE_ADDR, VGA_LINE_HEIGHT_OFFSET)      = VGA_ROWS;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_FRONT_PORCH_OFFSET) = 0x10;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_SYNC_OFFSET)        = 0x60;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_BACK_PORCH_OFFSET)  = 0x30;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_FRONT_PORCH_OFFSET) = 0x0A;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_SYNC_OFFSET)        = 0x02;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_BACK_PORCH_OFFSET)  = 0x21;
    clear_screen();
    *reg8(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;
}

void clear_screen(void) {
    for (int i = 0; i < VGA_COLS * VGA_ROWS / 2; i++) {
        *reg32(VGA_TB_BASE_ADDR, i * 4) = 0;
    }
}

void put_char(int x, int y, char c) {
    if (x < 0 || x >= VGA_COLS || y < 0 || y >= VGA_ROWS) {
        uart_write('?');
        return;
    }
    int offset = y * VGA_COLS + x;
    int idx    = x & 1;
    uint32_t w = *reg32(VGA_TB_BASE_ADDR, (offset / 2) * 4);
    w &= ~((uint32_t)0xFFFF << (16 * idx));
    w |= ((uint32_t)(uint8_t)c << (16 * idx));
    *reg32(VGA_TB_BASE_ADDR, (offset / 2) * 4) = w;
}

char get_char(int x, int y) {
    if (x < 0 || x >= VGA_COLS || y < 0 || y >= VGA_ROWS) return 0;
    int offset = y * VGA_COLS + x;
    int idx    = x & 1;
    uint32_t w = *reg32(VGA_TB_BASE_ADDR, (offset / 2) * 4);
    return (char)(w >> (16 * idx));
}
