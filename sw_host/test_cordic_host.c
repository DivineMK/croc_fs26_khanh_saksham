#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <x86intrin.h>
#include "../sw/lib/inc/cordic.h"

#define Q16_ONE 65536
#define QTOF(x) ((float)(x) / (float)Q16_ONE)
#define CORDIC_PI_F 3.14159265358979323846f
#define ANGLE_TO_RAD(a) ((float)(a) * 2.0f * CORDIC_PI_F / 4294967296.0f)

static const uint32_t angles[] = {
    0x00000000, 0x20000000, 0x40000000,
    0x80000000, 0xA0000000, 0xE0000000,
};
static const char *labels[] = {"0", "45", "90", "180", "225", "315"};
#define NUM_ANGLES (sizeof(angles) / sizeof(angles[0]))

int main(void) {
    printf("=== SW CORDIC vs math.h Error Analysis ===\n\n");

    printf("--- Sincos Mode ---\n");
    printf("  %-4s  | %-10s  %-10s  | %-12s  %-12s\n", "deg", "sin_err", "cos_err", "sin_abs_err", "cos_abs_err");

    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        float angle_rad = ANGLE_TO_RAD(angles[i]);
        float ref_sin = sinf(angle_rad);
        float ref_cos = cosf(angle_rad);

        int32_t sw_sin, sw_cos;
        cordic_sincos(angles[i], &sw_sin, &sw_cos);

        float err_sin = fabsf(QTOF(sw_sin) - ref_sin);
        float err_cos = fabsf(QTOF(sw_cos) - ref_cos);

        printf("  %3s   |  %.6f    %.6f   |  %5d       %5d\n",
               labels[i], err_sin, err_cos,
               sw_sin - (int32_t)(ref_sin * Q16_ONE),
               sw_cos - (int32_t)(ref_cos * Q16_ONE));
    }

    printf("\n--- MagPhase Mode: vector (1.0, 1.0) ---\n");
    {
        int32_t x = Q16_ONE, y = Q16_ONE;
        int32_t mag, phase;
        cordic_magphase(x, y, &mag, &phase);

        float ref_mag = sqrtf(2.0f);
        float ref_phase = atan2f(1.0f, 1.0f);
        float mag_err = fabsf(QTOF(mag) - ref_mag);
        float phase_err = fabsf(ANGLE_TO_RAD(phase) - ref_phase);

        printf("  mag_err=%.6f  phase_err=%.6f\n", mag_err, phase_err);
        printf("  mag_abs_err=%d  phase_abs_err=%d (Q16 units)\n",
               mag - (int32_t)(ref_mag * Q16_ONE),
               phase - (int32_t)(ref_phase / (2.0f * CORDIC_PI_F) * 4294967296.0f));
    }

    printf("\nDone.\n");
    return 0;
}
