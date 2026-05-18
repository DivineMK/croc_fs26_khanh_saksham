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

int main() {
    uart_init();
    printf("Hello VGA!\r\n");

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
        // printf("Setting up row %d\r\n", i);
        for (int j = 0; j < 80 / 2; j += 1) {
            //*reg32(VGA_TB_BASE_ADDR, (i * 20 / 2 + j) * 4) = i * 20 / 2 + j;
            *reg32(VGA_TB_BASE_ADDR, (i * 80 / 2 + j) * 4) =
                (((j & 0x1) << 1 | (i & 0x1)) << 16) | ((i & 0x1) << 1 | (j & 0x1));
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 1) = 0x00;
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 2) = (j & 0x1) << 1 | (i & 0x1);
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 3) = 0x00;
        }
    }

    printf("Start VGA\r\n");
    *reg8(VGA_REG_BASE_ADDR, VGA_EN_OFFSET) = 1;

    uart_write_flush();
    return 0;
}
