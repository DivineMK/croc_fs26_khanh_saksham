#include "uart.h"
#include "util.h"
#include "print.h"
#include "config.h"
#include "vga.h"

#define PADDLE_H        6
#define PADDLE_X_L      1
#define PADDLE_X_R      (VGA_COLS - 2)
#define BALL_CHAR       'o'
#define WALL_CHAR       '#'
#define PAD_CHAR        '|'
#define CYCLES_PER_MS   50000
#define TICK_MS         20
#define BALL_SPEED_INIT 4

static int paddle_l, paddle_r;
static int ball_x, ball_y;
static int ball_dx, ball_dy;
static int score_l, score_r;
static unsigned int frame;
static unsigned int ball_div;
static unsigned int ball_spd;

static char wait_for_key(void) {
    while (!uart_read_ready());
    return uart_read();
}

static void uart_puts(const char *s) {
    while (*s) uart_write(*s++);
}

static void put_str(int x, int y, const char *s) {
    for (int i = 0; s[i]; i++) put_char(x + i, y, s[i]);
}

static void draw_border(void) {
    for (int x = 0; x < VGA_COLS; x++) {
        put_char(x, 0, WALL_CHAR);
        put_char(x, VGA_ROWS - 1, WALL_CHAR);
    }
    for (int y = 1; y < VGA_ROWS - 1; y++) {
        put_char(0, y, WALL_CHAR);
        put_char(VGA_COLS - 1, y, WALL_CHAR);
    }
}

static void clear_paddle(int x, int y) {
    for (int i = 0; i < PADDLE_H; i++) put_char(x, y + i, ' ');
}

static void draw_paddle(int x, int y) {
    for (int i = 0; i < PADDLE_H; i++) put_char(x, y + i, PAD_CHAR);
}

static void draw_score(void) {
    put_char(VGA_COLS / 2 - 3, 0, '0' + score_l);
    put_char(VGA_COLS / 2 - 2, 0, ' ');
    put_char(VGA_COLS / 2 - 1, 0, ':');
    put_char(VGA_COLS / 2, 0, ' ');
    put_char(VGA_COLS / 2 + 1, 0, '0' + score_r);
}

static void show_speed(void) {
    put_str(VGA_COLS - 8, VGA_ROWS - 1, "spd");
    if (ball_spd >= 10) {
        put_char(VGA_COLS - 5, VGA_ROWS - 1, '1');
        put_char(VGA_COLS - 4, VGA_ROWS - 1, '0' + ball_spd - 10);
    } else {
        put_char(VGA_COLS - 5, VGA_ROWS - 1, '0' + ball_spd);
        put_char(VGA_COLS - 4, VGA_ROWS - 1, ' ');
    }
}

static void reset_ball(void) {
    ball_x  = VGA_COLS / 2;
    ball_y  = VGA_ROWS / 2;
    ball_dx = 1;
    ball_dy = 1;
}

static void reset_game(void) {
    clear_screen();
    draw_border();
    paddle_l = VGA_ROWS / 2 - PADDLE_H / 2;
    paddle_r = VGA_ROWS / 2 - PADDLE_H / 2;
    score_l  = 0;
    score_r  = 0;
    ball_div = BALL_SPEED_INIT;
    ball_spd = BALL_SPEED_INIT;
    reset_ball();
    draw_paddle(PADDLE_X_L, paddle_l);
    draw_paddle(PADDLE_X_R, paddle_r);
    put_char(ball_x, ball_y, BALL_CHAR);
    draw_score();
    show_speed();
}

static void show_menu(void) {
    clear_screen();
    put_str(38, 21, "PONG");
    put_str(32, 24, "j/k move left paddle");
    put_str(32, 25, "s/d change speed");
    put_str(32, 26, "AI on right paddle");
    put_str(30, 29, "Press any key to start");
    wait_for_key();
}

static void show_score(void) {
    int x;
    for (x = 1; x < VGA_COLS - 1; x++) put_char(x, 0, ' ');
    const char *side = (ball_x <= 0) ? "R" : "L";
    put_str(2, 0, side);
    put_str(3, 0, " scored  ");
    put_char(12, 0, '0' + score_l);
    put_char(13, 0, ':');
    put_char(14, 0, '0' + score_r);
    put_str(16, 0, "any key");

    wait_for_key();
    for (x = 0; x < VGA_COLS; x++) put_char(x, 0, WALL_CHAR);
    draw_score();
}

static void game_tick(void) {
    uint32_t start = (uint32_t)get_mcycle();
    while (uart_read_ready()) {
        char c = uart_read();
        if (c == 'k' && paddle_l > 1) paddle_l--;
        if (c == 'j' && paddle_l < VGA_ROWS - 1 - PADDLE_H) paddle_l++;
        if (c == 's' && ball_div < 16) {
            ball_div <<= 1;
            ball_spd >>= 1;
        }
        if (c == 'd' && ball_div > 1) {
            ball_div >>= 1;
            ball_spd <<= 1;
        }
        if (c == 'm') {
            show_menu();
            reset_game();
        }
        if (c == 3) {
            uart_puts("bye\r\n");
            while (1);
        }
    }
    while ((uint32_t)get_mcycle() - start < (uint32_t)(TICK_MS * CYCLES_PER_MS));
}

static void update_ai(void) {
    if (ball_dx != 1) return;
    int target = ball_y - PADDLE_H / 2;
    if (target < 1) target = 1;
    if (target > VGA_ROWS - 1 - PADDLE_H) target = VGA_ROWS - 1 - PADDLE_H;
    if (paddle_r < target)
        paddle_r++;
    else if (paddle_r > target)
        paddle_r--;
}

int main() {
    uart_init();
    vga_init();

    show_menu();
    reset_game();

    while (1) {
        frame++;
        int prev_l = paddle_l;
        int prev_r = paddle_r;

        if (!(frame & (ball_div - 1))) {
            put_char(ball_x, ball_y, ' ');

            ball_x += ball_dx;
            ball_y += ball_dy;

            if (ball_y <= 1) {
                ball_y  = 1;
                ball_dy = 1;
            }
            if (ball_y >= VGA_ROWS - 2) {
                ball_y  = VGA_ROWS - 2;
                ball_dy = -1;
            }

            if (ball_x == PADDLE_X_L + 1 && ball_dx == -1) {
                if (ball_y >= paddle_l && ball_y < paddle_l + PADDLE_H) {
                    ball_dx = 1;
                }
            }

            if (ball_x == PADDLE_X_R - 1 && ball_dx == 1) {
                if (ball_y >= paddle_r && ball_y < paddle_r + PADDLE_H) {
                    ball_dx = -1;
                }
            }

            if (ball_x <= 0 || ball_x >= VGA_COLS - 1) {
                if (ball_x <= 0)
                    score_r++;
                else
                    score_l++;
                if (score_l >= 9 || score_r >= 9) {
                    show_menu();
                    reset_game();
                } else {
                    show_score();
                    reset_ball();
                    put_char(ball_x, ball_y, BALL_CHAR);
                    draw_score();
                    game_tick();
                }
                continue;
            }

            update_ai();
        }

        put_char(ball_x, ball_y, BALL_CHAR);
        draw_score();
        show_speed();

        game_tick();

        if (prev_l != paddle_l) {
            clear_paddle(PADDLE_X_L, prev_l);
            draw_paddle(PADDLE_X_L, paddle_l);
        }
        if (prev_r != paddle_r) {
            clear_paddle(PADDLE_X_R, prev_r);
            draw_paddle(PADDLE_X_R, paddle_r);
        }
    }

    return 0;
}
