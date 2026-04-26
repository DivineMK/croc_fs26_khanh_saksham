#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <x86intrin.h> // For __rdtsc()
#include "../sw/lib/inc/cordic.h"

static inline uint64_t get_cycles() {
    return __rdtsc();
}

int main(void) {
    printf("Starting Host CORDIC vs Math.h Tests...\n");

    uint64_t t0, t1, t2, t3;

    // Test 1: Sincos of pi/4
    float angle_f = 0.78539816339f; // pi/4
    int32_t angle = (int32_t)(angle_f * 65536.0f); // Q16 representation
    int32_t sin_val, cos_val;

    t0 = get_cycles();
    cordic_sincos(angle, &sin_val, &cos_val);
    t1 = get_cycles();

    // Standard math.h equivalent
    t2 = get_cycles();
    float math_sin_f = sinf(angle_f);
    float math_cos_f = cosf(angle_f);
    t3 = get_cycles();

    int32_t expected_sin = (int32_t)(math_sin_f * 65536.0f);
    int32_t expected_cos = (int32_t)(math_cos_f * 65536.0f);

    float sin_err = fabs((float)(sin_val - expected_sin)) / fabs((float)expected_sin) * 100.0f;
    float cos_err = fabs((float)(cos_val - expected_cos)) / fabs((float)expected_cos) * 100.0f;

    printf("Angle: %d (Q16 for pi/4)\n", angle);
    printf("CORDIC Sin: %d\n", sin_val);
    printf("Math.h Sin: %d (RelErr: %.4f%%)\n", expected_sin, sin_err);
    printf("CORDIC Cos: %d\n", cos_val);
    printf("Math.h Cos: %d (RelErr: %.4f%%)\n", expected_cos, cos_err);
    printf("Host CPU Cycles for CORDIC sincos: %lu\n", t1 - t0);
    printf("Host CPU Cycles for Math.h sincos: %lu\n\n", t3 - t2);

    // Test 2: MagPhase of (x=1.0, y=1.0)
    float x_f = 1.0f;
    float y_f = 1.0f;
    int32_t x = (int32_t)(x_f * 65536.0f); // Q16 representation
    int32_t y = (int32_t)(y_f * 65536.0f); // Q16 representation
    int32_t mag, phase;

    t0 = get_cycles();
    cordic_magphase(x, y, &mag, &phase);
    t1 = get_cycles();

    // Standard math.h equivalent
    t2 = get_cycles();
    float math_mag_f = sqrtf(x_f * x_f + y_f * y_f);
    float math_phase_f = atan2f(y_f, x_f);
    t3 = get_cycles();

    int32_t expected_mag = (int32_t)(math_mag_f * 65536.0f);
    int32_t expected_phase = (int32_t)(math_phase_f * 65536.0f);

    float mag_err = fabs((float)(mag - expected_mag)) / fabs((float)expected_mag) * 100.0f;
    float phase_err = fabs((float)(phase - expected_phase)) / fabs((float)expected_phase) * 100.0f;

    printf("Vector: x=%d, y=%d (Q16 for 1.0, 1.0)\n", x, y);
    printf("CORDIC Mag: %d\n", mag);
    printf("Math.h Mag: %d (RelErr: %.4f%%)\n", expected_mag, mag_err);
    printf("CORDIC Phase: %d\n", phase);
    printf("Math.h Phase: %d (RelErr: %.4f%%)\n", expected_phase, phase_err);
    printf("Host CPU Cycles for CORDIC magphase: %lu\n", t1 - t0);
    printf("Host CPU Cycles for Math.h magphase: %lu\n\n", t3 - t2);

    printf("Host CORDIC Tests completed.\n");

    return 0;
}
