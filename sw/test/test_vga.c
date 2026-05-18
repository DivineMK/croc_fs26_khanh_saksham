#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"
#include "vga.h"

void screen_up(void) {
    int32_t offset;

    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 0;
    offset                                   = 0;
    for (; offset < (VGA_ROWS - 1) * VGA_COLS / 2; offset++)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset + VGA_COLS / 2) * 4);
    for (; offset < VGA_ROWS * VGA_COLS / 2; offset++) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;
}

void screen_down(void) {
    int32_t offset;

    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 0;
    for (offset = VGA_ROWS * VGA_COLS / 2 - 1; offset >= VGA_COLS / 2; offset--)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset - VGA_COLS / 2) * 4);
    for (offset = VGA_COLS / 2 - 1; offset >= 0; offset--) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;
}

int main() {
    uart_init();
    printf("Hello VGA!\r\n");
    vga_init();

    uint32_t char_pos_x = 0, char_pos_y = 0;
    uint32_t buf_off;
    uint8_t idx;
    uint32_t buffer;

    while (1) {
        while (uart_read_ready()) {
            char c = uart_read();
            switch (c) {
            case '\r':
            case '\n':
                char_pos_x = 0;
                char_pos_y += 1;
                if (char_pos_y >= VGA_ROWS) char_pos_y = 0;
                break;
            case 'j':
                screen_down();
                break;
            case 'k':
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
                buf_off = char_pos_y * VGA_COLS + char_pos_x;
                idx     = char_pos_x & 1;
                buffer  = *reg32(VGA_TB_BASE_ADDR, (buf_off / 2) * 4);
                buffer |= ((uint32_t)c << (16 * idx));
                *reg32(VGA_TB_BASE_ADDR, (buf_off / 2) * 4) = buffer;

                char_pos_x += 1;
                if (char_pos_x >= VGA_COLS) {
                    char_pos_x = 0;
                    char_pos_y += 1;
                    if (char_pos_y >= VGA_ROWS) char_pos_y = 0;
                }
                break;
            }
        }
    }

    uart_write_flush();
    return 0;
}
