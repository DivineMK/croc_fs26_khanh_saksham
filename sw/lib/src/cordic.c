#include "cordic.h"
#include "uart.h"
#include "util.h"

// Number of CORDIC iterations
#define CORDIC_ITERATIONS 16

// Pre-computed arctangents: atan(2^-i) in normalized format (2π = 2^32)
static const uint32_t atan_table[CORDIC_ITERATIONS] = {
    536870912,  // atan(2^0) = π/4  →  2^32 / 8
    316933406,  // atan(2^-1)
    167466358,  // atan(2^-2)
    85012769,   // atan(2^-3)
    42673528,   // atan(2^-4)
    21354918,   // atan(2^-5)
    10680707,   // atan(2^-6)
    5340354,    // atan(2^-7)
    2670177,    // atan(2^-8)
    1335088,    // atan(2^-9)
    667544,     // atan(2^-10)
    333772,     // atan(2^-11)
    166886,     // atan(2^-12)
    83443,      // atan(2^-13)
    41722,      // atan(2^-14)
    20861       // atan(2^-15)
};

void cordic_sincos(uint32_t angle, int32_t *sin_out, int32_t *cos_out) {
    int32_t x = CORDIC_K;
    int32_t y = 0;
    uint32_t z = angle;

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        int32_t y_temp = y;

        if (z < 0) {
            x = x_temp + (y_temp >> i);
            y = y_temp - (x_temp >> i);
            z += atan_table[i];
        } else {
            x = x_temp - (y_temp >> i);
            y = y_temp + (x_temp >> i);
            z -= atan_table[i];
        }
    }

    *cos_out = x;
    *sin_out = y;
}

void cordic_magphase(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out) {
    int32_t z = 0;

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        int32_t y_temp = y;

        if (y < 0) {
            x = x_temp - (y_temp >> i);
            y = y_temp + (x_temp >> i);
            z -= atan_table[i];
        } else {
            x = x_temp + (y_temp >> i);
            y = y_temp - (x_temp >> i);
            z += atan_table[i];
        }
    }

    // Multiply magnitude by 1/K (CORDIC_K) to compensate for gain
    // Since x is Q16, we do (x * CORDIC_K) >> 16
    *mag_out = (int32_t)(((int64_t)x * CORDIC_K) >> CORDIC_FRACTIONAL_BITS);
    *phase_out = z;
}
