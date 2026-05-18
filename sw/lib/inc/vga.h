#pragma once

#include <stdint.h>

#define VGA_TB_BASE_ADDR            0x10001000
#define VGA_REG_BASE_ADDR           0x20000000
#define VGA_TB_ADDR_OFFSET          0x0
#define VGA_CLK_DIV_OFFSET          0x4
#define VGA_EN_OFFSET               0x8
#define FSM_EN_OFFSET               0x0C
#define VGA_HSYNC_POL_OFFSET        0x10
#define VGA_VSYNC_POL_OFFSET        0x14
#define VGA_LINE_WIDTH_OFFSET       0x18
#define VGA_LINE_HEIGHT_OFFSET      0x1C
#define VGA_HORZ_FRONT_PORCH_OFFSET 0x20
#define VGA_HORZ_SYNC_OFFSET        0x24
#define VGA_HORZ_BACK_PORCH_OFFSET  0x28
#define VGA_VERT_FRONT_PORCH_OFFSET 0x2C
#define VGA_VERT_SYNC_OFFSET        0x30
#define VGA_VERT_BACK_PORCH_OFFSET  0x34
#define VGA_FONT_SRAM_OFFSET        0x200 // 0x100 + 32 control chars

#define VGA_COLS                    80
#define VGA_ROWS                    60

void vga_init(void);
void font_init(void);
void clear_screen(void);
void put_char(int x, int y, char c);
char get_char(int x, int y);
