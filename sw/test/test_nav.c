/*
 * test_nav.c -- Dead-reckoning navigation using CORDIC sincos.
 *
 * A robot takes N steps. Each step has a distance and heading angle.
 * For each step, compute:
 *   dx = distance * cos(heading)
 *   dy = distance * sin(heading)
 * Accumulate to get (x, y) position.
 *
 * Compares hw_sincos vs sw_sincos cycle count and accuracy.
 * This is the canonical embedded CORDIC application:
 *   - no FPU available
 *   - need sin/cos for coordinate transforms
 *   - real-time constraint (navigation loop)
 */
#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define Q16_ONE 65536
#define NUM_STEPS 64

/* Robot path: distance (Q15.16) and heading (degrees) per step */
static int32_t dist[NUM_STEPS];
static uint32_t heading_cordic[NUM_STEPS];

/* Results */
static int32_t x_sw, y_sw;
static int32_t x_hw, y_hw;

/* Convert degrees to CORDIC angle (2pi = 2^32) */
static uint32_t deg_to_cordic(int deg) {
    return (uint32_t)((uint64_t)deg * 11930465u);
}

static void gen_path(void) {
    for (int i = 0; i < NUM_STEPS; i++) {
        dist[i] = Q16_ONE / 2;  /* 0.5 in Q15.16 */
        heading_cordic[i] = deg_to_cordic((i * 5) % 360);
    }
}

int main(void) {
    uart_init();
    uint32_t start, end;

    cordic_set_precision(CORDIC_PREC_FULL);
    gen_path();

    /* ---- SW sincos navigation ---- */
    x_sw = 0;
    y_sw = 0;
    start = get_mcycle();
    for (int i = 0; i < NUM_STEPS; i++) {
        int32_t s, c;
        sw_sincos(heading_cordic[i], &s, &c);
        x_sw += (int32_t)(((int64_t)dist[i] * c) >> 16);
        y_sw += (int32_t)(((int64_t)dist[i] * s) >> 16);
    }
    end = get_mcycle();
    uint32_t sw_cycles = end - start;
    printf("sw_sincos:  x=%d y=%d  %d cycles\n", x_sw, y_sw, sw_cycles);

    /* ---- HW sincos navigation ---- */
    x_hw = 0;
    y_hw = 0;
    start = get_mcycle();
    for (int i = 0; i < NUM_STEPS; i++) {
        int32_t s, c;
        hw_sincos(heading_cordic[i], &s, &c);
        x_hw += (int32_t)(((int64_t)dist[i] * c) >> 16);
        y_hw += (int32_t)(((int64_t)dist[i] * s) >> 16);
    }
    end = get_mcycle();
    uint32_t hw_cycles = end - start;
    printf("hw_sincos:  x=%d y=%d  %d cycles\n", x_hw, y_hw, hw_cycles);

    /* ---- Accuracy check ---- */
    int32_t err_x = x_hw - x_sw;
    int32_t err_y = y_hw - y_sw;
    if (err_x < 0) err_x = -err_x;
    if (err_y < 0) err_y = -err_y;

    printf("error:      dx=%d dy=%d\n", err_x, err_y);

    if (err_x < 100 && err_y < 100) {
        /* Integer speedup: sw_cycles * 10 / hw_cycles gives one decimal */
        printf("nav: PASS  speedup=%d.%dx\n",
               sw_cycles / hw_cycles,
               (sw_cycles * 10 / hw_cycles) % 10);
    } else {
        printf("nav: FAIL\n");
    }

    /* ---- Round-trip: vector(3,4) -> heading ~53 deg, magnitude ~5 ---- */
    int32_t vx = 3 * Q16_ONE;
    int32_t vy = 4 * Q16_ONE;
    int32_t mag, angle;
    hw_vector(vx, vy, &mag, &angle);
    /* angle is uint32_t (CORDIC format). Convert to degrees using integer math:
       deg = (uint32_t)angle * 360 / 2^32
       Since 360 = 360 and 2^32 overflows 32-bit, do: deg = angle / (2^32/360)
       2^32/360 = 11930464.7, so deg = angle / 11930465 */
    uint32_t angle_deg = angle / 11930465u;
    printf("atan2(4,3): angle=%d deg (expect ~53)\n", (int)angle_deg);
    /* hw_vector magnitude is K-scaled, apply kc */
    int32_t mag_true = (int32_t)(((int64_t)mag * CORDIC_K) >> 16);
    printf("magnitude:  %d (expect %d)\n", mag_true, 5 * Q16_ONE);

    uart_write_flush();
    return 0;
}
