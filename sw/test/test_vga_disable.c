#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"
#include "vga.h"

int main() {
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET)               = 0;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET)               = 1;
    *reg32(VGA_REG_BASE_ADDR, VGA_EN_OFFSET)               = 0;
    return 0;
}
