#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

static const uint32_t angles[] = {
    0x00000000, // 0deg - cos > 0
    0x20000000, // 45deg - cos > 0
    0x40000000, // 90deg - cos = 0
    0x60000000, // 135deg - cos < 0
    0x80000000, // 180deg - cos < 0
    0xA0000000, // 225deg - cos < 0
    0xC0000000, // 270deg - cos = 0
    0xE0000000, // 315deg - cos > 0
};
static const char *angle_labels[] = {"0", "45", "90", "135", "180", "225", "270", "315"};

#define NUM_ANGLES (sizeof(angles) / sizeof(angles[0]))

static int check_match(const int32_t *ref, const int32_t *actual, int count) {
    return cmp_rel(ref, actual, count, 1, 200);
}

#define CYCLE_MODE

int main(void) {
    uart_init();
    cordic_set_drcg(1);
    cordic_set_precision(15);

    // =====================================================
    // SINCOS: sw_sincos vs hw_sincos
    // =====================================================
    unsigned pass     = 0;
    uint32_t sw_total = 0, hw_total = 0;
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos, hw_sin, hw_cos;
        uint32_t start, end, sw_cycles, hw_cycles;

        start = get_mcycle();
        sw_sincos(angle, &sw_sin, &sw_cos);
        end       = get_mcycle();
        sw_cycles = end - start;

        start     = get_mcycle();
        hw_sincos(angle, &hw_sin, &hw_cos);
        end       = get_mcycle();
        hw_cycles = end - start;

        int ok    = check_match(&sw_sin, &hw_sin, 1) && check_match(&sw_cos, &hw_cos, 1);
        if (ok) pass++;

#ifndef CYCLE_MODE
        printf("sincos a=%s sw=(%d,%d) hw=(%d,%d) sw_cyc=%d hw_cyc=%d %s\n", angle_labels[i], sw_sin, sw_cos, hw_sin,
               hw_cos, sw_cycles, hw_cycles, ok ? "PASS" : "FAIL");
#endif
        sw_total += sw_cycles;
        hw_total += hw_cycles;
    }
#ifdef CYCLE_MODE
    printf("sincos: sw_avg=%d hw_avg=%d %s\n", sw_total / NUM_ANGLES, hw_total / NUM_ANGLES,
           pass == NUM_ANGLES ? "PASS" : "FAIL");
#else
    printf("%d/%d SINCOS_PASS\n", pass, NUM_ANGLES);
#endif

    // =====================================================
    // ROTATE: sw_rotate vs hw_rotate
    // Reference: sw_sincos + rotation matrix
    // =====================================================
    int32_t input_x = 65536, input_y = 0;
    pass     = 0;
    sw_total = 0;
    hw_total = 0;
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos;
        int32_t expected_x, expected_y;
        int32_t sw_out_x, sw_out_y, hw_out_x, hw_out_y;
        uint32_t start, end, sw_cycles, hw_cycles;

        sw_sincos(angle, &sw_sin, &sw_cos);
        expected_x = (int32_t)(((int64_t)input_x * sw_cos - (int64_t)input_y * sw_sin) >> 16);
        expected_y = (int32_t)(((int64_t)input_x * sw_sin + (int64_t)input_y * sw_cos) >> 16);

        start      = get_mcycle();
        sw_rotate(input_x, input_y, angle, &sw_out_x, &sw_out_y);
        end       = get_mcycle();
        sw_cycles = end - start;
        sw_out_x  = (int32_t)(((int64_t)sw_out_x * CORDIC_K) >> 16);
        sw_out_y  = (int32_t)(((int64_t)sw_out_y * CORDIC_K) >> 16);

        start     = get_mcycle();
        hw_rotate(input_x, input_y, angle, &hw_out_x, &hw_out_y);
        end       = get_mcycle();
        hw_cycles = end - start;
        hw_out_x  = (int32_t)(((int64_t)hw_out_x * CORDIC_K) >> 16);
        hw_out_y  = (int32_t)(((int64_t)hw_out_y * CORDIC_K) >> 16);

        int ok    = check_match(&expected_x, &sw_out_x, 1) && check_match(&expected_y, &sw_out_y, 1) &&
                    check_match(&expected_x, &hw_out_x, 1) && check_match(&expected_y, &hw_out_y, 1);
        if (ok) pass++;

#ifndef CYCLE_MODE
        printf("rotate a=%s sw=(%d,%d) hw=(%d,%d) ref=(%d,%d) sw_cyc=%d hw_cyc=%d %s\n", angle_labels[i], sw_out_x,
               sw_out_y, hw_out_x, hw_out_y, expected_x, expected_y, sw_cycles, hw_cycles, ok ? "PASS" : "FAIL");
#endif
        sw_total += sw_cycles;
        hw_total += hw_cycles;
    }
#ifdef CYCLE_MODE
    printf("rotate: sw_avg=%d hw_avg=%d %s\n", sw_total / NUM_ANGLES, hw_total / NUM_ANGLES,
           pass == NUM_ANGLES ? "PASS" : "FAIL");
#else
    printf("%d/%d ROTATE_PASS\n", pass, NUM_ANGLES);
#endif

    // =====================================================
    // VECTOR: sw_vector vs hw_vector
    // Feed unit vector at known angle, verify phase matches
    // =====================================================
    pass     = 0;
    sw_total = 0;
    hw_total = 0;
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos;
        sw_sincos(angle, &sw_sin, &sw_cos);

        int32_t sw_mag, sw_phase, hw_mag, hw_phase;
        uint32_t start, end, sw_cycles, hw_cycles;

        start = get_mcycle();
        sw_vector(sw_cos, sw_sin, &sw_mag, &sw_phase);
        end       = get_mcycle();
        sw_cycles = end - start;

        start     = get_mcycle();
        hw_vector(sw_cos, sw_sin, &hw_mag, &hw_phase);
        end       = get_mcycle();
        hw_cycles = end - start;

        // Both are K-scaled, compare directly
        int ok    = check_match(&sw_mag, &hw_mag, 1) && check_match(&sw_phase, &hw_phase, 1);
        if (ok) pass++;

#ifndef CYCLE_MODE
        printf("vector a=%s sw=(%d,%d) hw=(%d,%d) sw_cyc=%d hw_cyc=%d %s\n", angle_labels[i], sw_mag, sw_phase, hw_mag,
               hw_phase, sw_cycles, hw_cycles, ok ? "PASS" : "FAIL");
#endif
        sw_total += sw_cycles;
        hw_total += hw_cycles;
    }
#ifdef CYCLE_MODE
    printf("vector: sw_avg=%d hw_avg=%d %s\n", sw_total / NUM_ANGLES, hw_total / NUM_ANGLES,
           pass == NUM_ANGLES ? "PASS" : "FAIL");
#else
    printf("%d/%d VECTOR_PASS\n", pass, NUM_ANGLES);
#endif

    uart_write_flush();
    return 0;
}
