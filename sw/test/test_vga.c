#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"
#include "vga.h"

void screen_up(void) {
    int32_t offset;

    offset = 0;
    for (; offset < (VGA_ROWS - 1) * VGA_COLS / 2; offset++)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset + VGA_COLS / 2) * 4);
    for (; offset < VGA_ROWS * VGA_COLS / 2; offset++) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
}

void screen_down(void) {
    int32_t offset;

    for (offset = VGA_ROWS * VGA_COLS / 2 - 1; offset >= VGA_COLS / 2; offset--)
        *reg32(VGA_TB_BASE_ADDR, offset * 4) = *reg32(VGA_TB_BASE_ADDR, (offset - VGA_COLS / 2) * 4);
    for (offset = VGA_COLS / 2 - 1; offset >= 0; offset--) *reg32(VGA_TB_BASE_ADDR, offset * 4) = 0;
}

int main() {
    uart_init();
    printf("Hello VGA!\r\n");
    vga_init();

    uint32_t char_pos_x = 2, char_pos_y = 0;
    uint32_t buf_off;
    uint8_t idx;
    uint32_t buffer;

    *reg32(VGA_TB_BASE_ADDR, 0) = '>';
    while (1) {
        while (uart_read_ready()) {
            char c = uart_read();
            printf("char_pos_x: %d, char_pos_y: %d, %c\r\n", char_pos_x, char_pos_y, c);
            switch (c) {
            case '\r':
            case '\n':
                char_pos_x = 2;
                if (char_pos_y < VGA_ROWS - 1)
                    char_pos_y += 1;
                else
                    screen_up();
                *reg32(VGA_TB_BASE_ADDR, char_pos_y * VGA_COLS * 2) = '>';
                break;
            case 'j':
                screen_down();
                break;
            case 'k':
                screen_up();
                break;
            case 8:   // Backspace
            case 127: // Delete
                if (char_pos_x > 2) {
                    char_pos_x -= 1;
                }
                buf_off = char_pos_y * VGA_COLS + char_pos_x;
                idx     = char_pos_x & 1;
                buffer  = *reg32(VGA_TB_BASE_ADDR, (buf_off / 2) * 4);
                buffer &= ~((uint32_t)0xFFFF << (16 * idx));
                *reg32(VGA_TB_BASE_ADDR, (buf_off / 2) * 4) = buffer;
                break;
            case 12: // Ctrl-L
                clear_screen();
                char_pos_x                  = 2;
                char_pos_y                  = 0;
                *reg32(VGA_TB_BASE_ADDR, 0) = '>';
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
                    char_pos_x = 2;
                    if (char_pos_y < VGA_ROWS - 1)
                        char_pos_y += 1;
                    else
                        screen_up();
                    *reg32(VGA_TB_BASE_ADDR, char_pos_y * VGA_COLS * 2) = '>';
                }
                break;
            }
        }
    }

    uart_write_flush();
    return 0;
}
