#include "cordic.h"

// Number of CORDIC iterations
#define CORDIC_ITERATIONS 16

// Pre-computed arctangents: atan(2^-i) in Q15.16 format
// Computed as: round(atan(2^-i) * 2^16)
static const int32_t atan_table[CORDIC_ITERATIONS] = {
    51472,  // atan(2^0) = 0.785398
    30386,  // atan(2^-1) = 0.463647
    16055,  // atan(2^-2) = 0.244978
    8150,   // atan(2^-3) = 0.124354
    4091,   // atan(2^-4) = 0.062418
    2047,   // atan(2^-5) = 0.031239
    1024,   // atan(2^-6) = 0.015623
    512,    // atan(2^-7) = 0.007812
    256,    // atan(2^-8) = 0.003906
    128,    // atan(2^-9) = 0.001953
    64,     // atan(2^-10) = 0.000976
    32,     // atan(2^-11) = 0.000488
    16,     // atan(2^-12) = 0.000244
    8,      // atan(2^-13) = 0.000122
    4,      // atan(2^-14) = 0.000061
    2       // atan(2^-15) = 0.000030
};

void cordic_sincos(int32_t angle, int32_t *sin_out, int32_t *cos_out) {
    int32_t x = CORDIC_K;
    int32_t y = 0;
    int32_t z = angle;

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
