#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"

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
#define VGA_FONT_SRAM_OFFSET        0x100

void font_init(void) {
    // 4 font patterns, each 8 rows of 8 pixels.
    // The same 4 patterns repeat for all 256 entries.
    static const uint8_t font_data[4][8] = {
        { // Pattern 0: 'A'
            0b00000000, // ........
            0b00010000, // ...X....
            0b00111000, // ..XXX...
            0b01101100, // .XX.XX..
            0b01101100, // .XX.XX..
            0b11111110, // XXXXXXX.
            0b11000110, // XX...XX.
            0b00000000, // ........
        },
        { // Pattern 1: 'B'
            0b00000000, // ........
            0b11111100, // XXXXXX..
            0b01100110, // .XX..XX.
            0b01111100, // .XXXXX..
            0b01100110, // .XX..XX.
            0b01100110, // .XX..XX.
            0b11111100, // XXXXXX..
            0b00000000, // ........
        },
        { // Pattern 2: 'C'
            0b00000000, // ........
            0b01111100, // .XXXXX..
            0b11000110, // XX...XX.
            0b11000000, // XX......
            0b11000000, // XX......
            0b11000110, // XX...XX.
            0b01111100, // .XXXXX..
            0b00000000, // ........
        },
        { // Pattern 3: 'D'
            0b00000000, // ........
            0b11111100, // XXXXXX..
            0b01100110, // .XX..XX.
            0b01100110, // .XX..XX.
            0b01100110, // .XX..XX.
            0b01100110, // .XX..XX.
            0b11111100, // XXXXXX..
            0b00000000, // ........
        },
    };

    for (int i = 0; i < 256; i++) {
        const uint8_t *ch = font_data[i % 4];
        // RTL stores font word as {row7,...,row0} = [63:0] where row7 is top.
        // OBI addr[2]=0 writes to [31:0], addr[2]=1 to [63:32].
        // Upper word [63:32] gets top 4 rows (ch[0..3]), lower word [31:0] gets bottom 4 (ch[4..7]).
        uint32_t hi = ((uint32_t)ch[0] << 24) | ((uint32_t)ch[1] << 16)
                    | ((uint32_t)ch[2] <<  8) |  (uint32_t)ch[3];
        uint32_t lo = ((uint32_t)ch[4] << 24) | ((uint32_t)ch[5] << 16)
                    | ((uint32_t)ch[6] <<  8) |  (uint32_t)ch[7];
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i)     = lo;
        *reg32(VGA_REG_BASE_ADDR, VGA_FONT_SRAM_OFFSET + 8 * i + 4) = hi;
    }
}

int main() {
    uart_init();
    printf("Hello VGA!\r\n");

    // font_init();
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

    for (int i = 0; i < 25; i += 1) {
        for (int j = 0; j < 80 / 2; j += 1) {
            *reg32(VGA_TB_BASE_ADDR, (i * 80 / 2 + j) * 4) =
                (((j & 0x1) << 1 | (i & 0x1)) << 16) | ((i & 0x1) << 1 | (j & 0x1));
        }
    }

    printf("Start VGA\r\n");
    *reg8(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;

    uart_write_flush();
    return 0;
}
