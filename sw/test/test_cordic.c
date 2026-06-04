#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"
#include "config.h"

#define ABS(x) ((x) < 0 ? -(x) : (x))

#ifdef CORDIC_IRQ
static volatile int cordic_done = 0;
static volatile int32_t sin_val, cos_val;

void croc_interrupt_handler(uint32_t cause) {
    if (cause == IRQ_CORDIC) {
        cos_val     = *reg32(CORDIC_BASE_ADDR, OUTPUT_X_OFFSET);
        sin_val     = *reg32(CORDIC_BASE_ADDR, OUTPUT_Y_OFFSET);
        cordic_done = 1;
    }
}
#endif


/**
 * @brief Polls the hardware CORDIC for sine and cosine values
 * @param angle Angle in normalized format (2π = 2^32).
 * @param sin_out Pointer to store the computed sine value (Q15.16 format).
 * @param cos_out Pointer to store the computed cosine value (Q15.16 format).
 */
static inline __attribute__((always_inline)) void hw_poll_cordic_sincos(uint32_t angle, int32_t *sin_val,
                                                                        int32_t *cos_val) {
    *reg32(CORDIC_BASE_ADDR, INPUT_OFFSET) = angle;
#ifdef CORDIC_IRQ
    while (cordic_done == 0) {
#else
    while (*reg32(CORDIC_BASE_ADDR, STATUS_OFFSET) == 1) {
#endif
        // Wait for operation to complete
    }
#ifndef CORDIC_IRQ
    *cos_val = *reg32(CORDIC_BASE_ADDR, OUTPUT_X_OFFSET);
    *sin_val = *reg32(CORDIC_BASE_ADDR, OUTPUT_Y_OFFSET);
#endif
}

int main(void) {
    uart_init();

#ifdef CORDIC_IRQ
    set_interrupt_enable(1, IRQ_CORDIC);
    set_global_irq_enable(1);
#endif

    printf("Starting CORDIC Tests...\n");

    uint32_t t0, t1;
    uint32_t hw_t0, hw_t1;

    // Test 1: Sincos of 3pi/4
    // 2^32 * 3 / 8
    uint32_t angle = (0b11 << 29);
    int32_t hw_sin_val, hw_cos_val;

    // t0 = get_mcycle();
    // cordic_sincos(angle, &sin_val, &cos_val);
    // t1 = get_mcycle();

    // printf("Starting HW CORDIC Tests...\n");
    hw_t0 = get_mcycle();
    hw_poll_cordic_sincos(angle, &hw_sin_val, &hw_cos_val);
    hw_t1 = get_mcycle();

    // int32_t expected_sin = 46340; // ~0.7071 * 65536
    // int32_t expected_cos = 46340;
    //
    // int32_t sin_err = (ABS(sin_val - expected_sin) * 100000) / ABS(expected_sin);
    // int32_t cos_err = (ABS(cos_val - expected_cos) * 100000) / ABS(expected_cos);
    //
    // int32_t hw_sin_err   = (ABS(hw_sin_val - expected_sin) * 100000) / ABS(expected_sin);
    // int32_t hw_cos_err   = (ABS(hw_cos_val - expected_cos) * 100000) / ABS(expected_cos);
    //
    // printf("Angle: %d (Q16 for pi/4)\n", angle);
    // printf("Angle: %d (normalized)\n", angle);
    // printf("Software CORDIC Sin: %d (Expected: %d, RelErr: %d / 100000)\n", sin_val, expected_sin, sin_err);
    // printf("Software CORDIC Cos: %d (Expected: %d, RelErr: %d / 100000)\n", cos_val, expected_cos, cos_err);
    // printf("Hardware CORDIC Sin: %d (Expected: %d, RelErr: %d / 100000)\n", hw_sin_val, expected_sin, hw_sin_err);
    // printf("Hardware CORDIC Cos: %d (Expected: %d, RelErr: %d / 100000)\n", hw_cos_val, expected_cos, hw_cos_err);
    // // printf("Cycles for sw sincos: %d\n\n", t1 - t0);
    printf("Cycles for hardware sincos: %d\n\n", hw_t1 - hw_t0);
    printf("Hardware CORDIC Sin: %d\n", hw_sin_val);
    printf("Hardware CORDIC Cos: %d\n", hw_cos_val);

    // Test 2: MagPhase of (x=1.0, y=1.0)
    // 1.0 * 65536 = 65536
    // int32_t x = 65536;
    // int32_t y = 65536;
    // int32_t mag, phase;
    //
    // t0 = get_mcycle();
    // cordic_magphase(x, y, &mag, &phase);
    // t1 = get_mcycle();
    //
    // int32_t expected_mag = 92681; // ~1.4142 * 65536
    // int32_t expected_phase = 51472; // ~0.785398 * 65536
    // int32_t expected_phase = 536870912; // pi/4 in normalized format
    //
    // int32_t mag_err = (ABS(mag - expected_mag) * 100000) / ABS(expected_mag);
    // int32_t phase_err = (ABS(phase - expected_phase) * 100000) / ABS(expected_phase);
    //
    // printf("Vector: x=%d, y=%d (Q16 for 1.0, 1.0)\n", x, y);
    // printf("CORDIC Mag: %d (Expected: %d, RelErr: %d / 100000)\n", mag, expected_mag, mag_err);
    // printf("CORDIC Phase: %d (Expected: %d, RelErr: %d / 100000)\n", phase, expected_phase, phase_err);
    // printf("Cycles for magphase: %d\n\n", t1 - t0);

    // printf("CORDIC Tests completed.\n");

    uart_write_flush();
    return 0;
}
