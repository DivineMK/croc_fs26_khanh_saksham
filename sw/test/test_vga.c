#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"

#define VGA_TB_BASE_ADDR       0x10001000
#define VGA_REG_BASE_ADDR      0x20000000
#define VGA_REG_TB_ADDR_OFFSET 0x0
#define VGA_REG_CLK_DIV_OFFSET 0x4
#define VGA_REG_EN_OFFSET      0x8

int main() {
    uart_init();
    printf("Hello VGA!\n");

    *reg32(VGA_REG_BASE_ADDR, VGA_REG_TB_ADDR_OFFSET) = VGA_TB_BASE_ADDR;
    printf("Setting up VGA_TB_BASE_ADDR\n");
    *reg32(VGA_REG_BASE_ADDR, VGA_REG_CLK_DIV_OFFSET) = 0x2;
    printf("Setting up VGA_REG_CLK_DIV_OFFSET\n");
    *reg32(VGA_REG_BASE_ADDR, VGA_REG_EN_OFFSET) = 0x0;
    printf("Setting up VGA_REG_EN_OFFSET\n");

    for (int i = 0; i < 5; i += 1) {
        printf("Setting up row %d\n", i);
        for (int j = 0; j < 20 / 2; j += 1) {
            //*reg32(VGA_TB_BASE_ADDR, (i * 20 / 2 + j) * 4) = i * 20 / 2 + j;
            *reg32(VGA_TB_BASE_ADDR, (i * 20 / 2 + j) * 4) =
                (((i & 0x1) << 1 | (j & 0x1)) << 16) | ((j & 0x1) << 1 | (i & 0x1));
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 1) = 0x00;
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 2) = (j & 0x1) << 1 | (i & 0x1);
            // *reg8(VGA_TB_BASE_ADDR, ((i + 0) * 80 / 2 + j) * 4 + 3) = 0x00;
        }
    }

    *reg8(VGA_REG_BASE_ADDR, VGA_REG_EN_OFFSET) = 0x1;

    uart_write_flush();
    return 0;
}
