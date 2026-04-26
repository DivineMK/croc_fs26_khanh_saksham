#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"
#include "config.h"

#define ABS(x) ((x) < 0 ? -(x) : (x))

int main(void) {
    uart_init();

    printf("Starting CORDIC Tests...\n");

    uint32_t t0, t1;

    // Test 1: Sincos of pi/4 (0.785398)
    // 0.785398 * 65536 = 51471.8 => 51472
    int32_t angle = 51472;
    int32_t sin_val, cos_val;
    
    t0 = get_mcycle();
    cordic_sincos(angle, &sin_val, &cos_val);
    t1 = get_mcycle();

    int32_t expected_sin = 46340; // ~0.7071 * 65536
    int32_t expected_cos = 46340;

    int32_t sin_err = (ABS(sin_val - expected_sin) * 100000) / ABS(expected_sin);
    int32_t cos_err = (ABS(cos_val - expected_cos) * 100000) / ABS(expected_cos);

    printf("Angle: %d (Q16 for pi/4)\n", angle);
    printf("CORDIC Sin: %d (Expected: %d, RelErr: %d / 100000)\n", sin_val, expected_sin, sin_err);
    printf("CORDIC Cos: %d (Expected: %d, RelErr: %d / 100000)\n", cos_val, expected_cos, cos_err);
    printf("Cycles for sincos: %d\n\n", t1 - t0);

    // Test 2: MagPhase of (x=1.0, y=1.0)
    // 1.0 * 65536 = 65536
    int32_t x = 65536;
    int32_t y = 65536;
    int32_t mag, phase;
    
    t0 = get_mcycle();
    cordic_magphase(x, y, &mag, &phase);
    t1 = get_mcycle();

    int32_t expected_mag = 92681; // ~1.4142 * 65536
    int32_t expected_phase = 51472; // ~0.785398 * 65536

    int32_t mag_err = (ABS(mag - expected_mag) * 100000) / ABS(expected_mag);
    int32_t phase_err = (ABS(phase - expected_phase) * 100000) / ABS(expected_phase);

    printf("Vector: x=%d, y=%d (Q16 for 1.0, 1.0)\n", x, y);
    printf("CORDIC Mag: %d (Expected: %d, RelErr: %d / 100000)\n", mag, expected_mag, mag_err);
    printf("CORDIC Phase: %d (Expected: %d, RelErr: %d / 100000)\n", phase, expected_phase, phase_err);
    printf("Cycles for magphase: %d\n\n", t1 - t0);

    printf("CORDIC Tests completed.\n");
    
    uart_write_flush();
    return 0;
}
