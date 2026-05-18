#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"
#include "font_8x8.h"

#define VGA_TB_BASE_ADDR            0x10001000
#define VGA_REG_BASE_ADDR           0x20000000
#define VGA_TB_ADDR_OFFSET          0x0
#define VGA_CLK_DIV_OFFSET          0x4
#define VGA_EN_OFFSET               0x8
#define VGA_HSYNC_POL_OFFSET        0x0C
#define VGA_VSYNC_POL_OFFSET        0x10
#define VGA_LINE_WIDTH_OFFSET       0x14
#define VGA_LINE_HEIGHT_OFFSET      0x18
#define VGA_HORZ_FRONT_PORCH_OFFSET 0x1C
#define VGA_HORZ_SYNC_OFFSET        0x20
#define VGA_HORZ_BACK_PORCH_OFFSET  0x24
#define VGA_VERT_FRONT_PORCH_OFFSET 0x28
#define VGA_VERT_SYNC_OFFSET        0x2C
#define VGA_VERT_BACK_PORCH_OFFSET  0x30
#define VGA_FONT_SRAM_OFFSET        0x200 // skip 0-31 control characters

#define LINE_WIDTH                  80
#define LINE_HEIGHT                 60

void font_init(void) {
    for (int i = 0; i < 96; i++) {
        // font in font_8x8.h
        const uint8_t *ch = fontdata_8x8[i];
        uint32_t hi = ((uint32_t)ch[0] << 24) | ((uint32_t)ch[1] << 16) | ((uint32_t)ch[2] << 8) | (uint32_t)ch[3];
        uint32_t lo = ((uint32_t)ch[4] << 24) | ((uint32_t)ch[5] << 16) | ((uint32_t)ch[6] << 8) | (uint32_t)ch[7];
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i)     = lo;
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i + 4) = hi;
    }
}

void clear_screen(void) {
    for (int i = 0; i < LINE_WIDTH * LINE_HEIGHT / 2; i++) {
        *reg32(VGA_TB_BASE_ADDR, i * 4) = 0;
    }
}

void screen_up(void) {
    int32_t offset, buffer;

    offset = 0;
    for (; offset < (LINE_HEIGHT - 1) * LINE_WIDTH / 2; offset++)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset + LINE_WIDTH / 2) * 4);
    for (; offset < LINE_HEIGHT * LINE_WIDTH / 2; offset++) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;
}

void screen_down(void) {
    int32_t offset, buffer;

    for (offset = LINE_HEIGHT * LINE_WIDTH / 2 - 1; offset >= LINE_WIDTH / 2; offset--)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset - LINE_WIDTH / 2) * 4);
    for (offset = LINE_WIDTH / 2 - 1; offset >= 0; offset--) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;
}

int main() {
    uart_init();
    printf("Hello VGA!\r\n");
    clear_screen();

    font_init();
    // printf("Font initialized\r\n");

    *reg32(VGA_REG_BASE_ADDR, VGA_TB_ADDR_OFFSET)          = VGA_TB_BASE_ADDR;
    *reg32(VGA_REG_BASE_ADDR, VGA_CLK_DIV_OFFSET)          = 2;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET)               = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_HSYNC_POL_OFFSET)        = 1;
    *reg32(VGA_REG_BASE_ADDR, VGA_VSYNC_POL_OFFSET)        = 1;
    *reg32(VGA_REG_BASE_ADDR, VGA_LINE_WIDTH_OFFSET)       = 80;
    *reg32(VGA_REG_BASE_ADDR, VGA_LINE_HEIGHT_OFFSET)      = 60;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_FRONT_PORCH_OFFSET) = 0x10;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_SYNC_OFFSET)        = 0x60;
    *reg32(VGA_REG_BASE_ADDR, VGA_HORZ_BACK_PORCH_OFFSET)  = 0x30;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_FRONT_PORCH_OFFSET) = 0x0A;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_SYNC_OFFSET)        = 0x02;
    *reg32(VGA_REG_BASE_ADDR, VGA_VERT_BACK_PORCH_OFFSET)  = 0x21;

    uint32_t char_pos_x = 0, char_pos_y = 0, offset = 0;
    uint32_t buffer = 0;
    uint8_t idx;

    for (int offset = 0; offset < 96 / 2; offset += 1) {
        buffer                               = offset * 2 + 32;
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = ((buffer + 1) << 16) | buffer;
    }
    *reg8(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;

    while (1) {
        while (uart_read_ready()) {
            char c = uart_read();
            switch (c) {
            case '\r':
            case '\n':
                printf("\\r received\r\n");
                char_pos_x = 0;
                char_pos_y += 1;
                if (char_pos_y >= LINE_HEIGHT) {
                    char_pos_y = 0;
                }
                break;
            case 'j':
                printf("char_pos_x: %d, char_pos_y: %d - %d:%c\r\n", char_pos_x, char_pos_y, c, c);
                screen_down();
                break;
            case 'k':
                printf("char_pos_x: %d, char_pos_y: %d - %d:%c\r\n", char_pos_x, char_pos_y, c, c);
                screen_up();
                break;
            case 12:
                clear_screen();
                char_pos_x = 0;
                char_pos_y = 0;
                break;
            case 3:
                printf("Ctrl-C received, exiting...\r\n");
                while (1);
            default:
                offset = char_pos_y * LINE_WIDTH + char_pos_x;
                idx    = char_pos_x & 1;
                buffer = *reg32(VGA_TB_BASE_ADDR, offset / 2 * 4);
                buffer |= ((uint32_t)c << (16 * idx));
                printf("char_pos_x: %d, char_pos_y: %d - %d:%c\r\n", char_pos_x, char_pos_y, c, c);
                *reg32(VGA_TB_BASE_ADDR, offset / 2 * 4) = buffer;

                char_pos_x += 1;
                if (char_pos_x >= LINE_WIDTH) {
                    char_pos_x = 0;
                    char_pos_y += 1;
                    if (char_pos_y >= LINE_HEIGHT) {
                        char_pos_y = 0;
                    }
                }
                break;
            }
        }
    }

    uart_write_flush();
    return 0;
}
