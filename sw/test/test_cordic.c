#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

static const uint32_t angles[] = {
    0x00000000, 0x20000000, 0x40000000,
    0x80000000, 0xA0000000, 0xE0000000,
};
static const char *angle_labels[] = {"0", "45", "90", "180", "225", "315"};

#define NUM_ANGLES (sizeof(angles) / sizeof(angles[0]))

/** Fill array with a constant value. */
static void fill_array(int32_t *dst, int32_t value, int count) {
    for (int i = 0; i < count; i++) dst[i] = value;
}

/** Save current data as reference for comparison. */
static void save_reference(const int32_t *src_re, const int32_t *src_im,
                           int32_t *dst_re, int32_t *dst_im, int count) {
    for (int i = 0; i < count; i++) {
        dst_re[i] = src_re[i];
        dst_im[i] = src_im[i];
    }
}

/** Check if two arrays match within tolerance. */
static int check_match(const int32_t *ref, const int32_t *actual, int count) {
    return cmp_rel(ref, actual, count, 1, 200);
}

int main(void) {
    uart_init();
    unsigned pass = 0;

    /* DRCG workaround: precision_q resets to 0 on gated clock domain. */
    cordic_set_precision(15);

    /* ---- Sincos mode: compare SW and HW CORDIC for each angle ---- */
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos, hw_sin, hw_cos;
        uint32_t start, end, sw_cycles, hw_cycles;

        start = get_mcycle();
        cordic_sincos(angle, &sw_sin, &sw_cos);
        end = get_mcycle();
        sw_cycles = end - start;

        start = get_mcycle();
        hw_sincos(angle, &hw_sin, &hw_cos);
        end = get_mcycle();
        hw_cycles = end - start;

        int ok = check_match(&sw_sin, &hw_sin, 1) &&
                 check_match(&sw_cos, &hw_cos, 1);
        if (ok) pass++;

        printf("sincos a=%s sw=(%d,%d) hw=(%d,%d) sw_cyc=%d hw_cyc=%d %s\n",
               angle_labels[i], sw_sin, sw_cos, hw_sin, hw_cos,
               sw_cycles, hw_cycles, ok ? "PASS" : "FAIL");
    }
    printf("%d/%d SINCOS_PASS\n", pass, NUM_ANGLES);

    /* ---- Vector mode: rotate (Q16_ONE, 0) by each angle using HW CORDIC ---- */
    int32_t input_x = 65536, input_y = 0;
    pass = 0;
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos;
        int32_t expected_x, expected_y;
        int32_t hw_out_x, hw_out_y;
        uint32_t start, end, hw_cycles;

        /* Compute expected result using SW sincos + rotation matrix */
        cordic_sincos(angle, &sw_sin, &sw_cos);
        expected_x = (int32_t)(((int64_t)input_x * sw_cos - (int64_t)input_y * sw_sin) >> 16);
        expected_y = (int32_t)(((int64_t)input_x * sw_sin + (int64_t)input_y * sw_cos) >> 16);

        /* HW rotate output is K-gain scaled; compensate with kc() */
        start = get_mcycle();
        hw_rotate(input_x, input_y, angle, &hw_out_x, &hw_out_y);
        end = get_mcycle();
        hw_cycles = end - start;
        hw_out_x = (int32_t)(((int64_t)hw_out_x * CORDIC_K) >> 16);
        hw_out_y = (int32_t)(((int64_t)hw_out_y * CORDIC_K) >> 16);

        int ok = check_match(&expected_x, &hw_out_x, 1) &&
                 check_match(&expected_y, &hw_out_y, 1);
        if (ok) pass++;

        printf("vec a=%s ref=(%d,%d) hw=(%d,%d) hw_cyc=%d %s\n",
               angle_labels[i], expected_x, expected_y, hw_out_x, hw_out_y,
               hw_cycles, ok ? "PASS" : "FAIL");
    }
    printf("%d/%d VEC_PASS\n", pass, NUM_ANGLES);

    /* ---- SW rotate mode: rotate (Q16_ONE, 0) by each angle in pure SW ---- */
    pass = 0;
    for (unsigned i = 0; i < NUM_ANGLES; i++) {
        uint32_t angle = angles[i];
        int32_t sw_sin, sw_cos;
        int32_t expected_x, expected_y;
        int32_t sw_out_x, sw_out_y;
        uint32_t start, end, sw_cycles;

        /* Compute expected result using SW sincos + rotation matrix */
        cordic_sincos(angle, &sw_sin, &sw_cos);
        expected_x = (int32_t)(((int64_t)input_x * sw_cos - (int64_t)input_y * sw_sin) >> 16);
        expected_y = (int32_t)(((int64_t)input_x * sw_sin + (int64_t)input_y * sw_cos) >> 16);

        /* SW rotate output is K-gain scaled; compensate with kc() */
        start = get_mcycle();
        sw_rotate(input_x, input_y, angle, &sw_out_x, &sw_out_y);
        end = get_mcycle();
        sw_cycles = end - start;
        sw_out_x = (int32_t)(((int64_t)sw_out_x * CORDIC_K) >> 16);
        sw_out_y = (int32_t)(((int64_t)sw_out_y * CORDIC_K) >> 16);

        int ok = check_match(&expected_x, &sw_out_x, 1) &&
                 check_match(&expected_y, &sw_out_y, 1);
        if (ok) pass++;

        printf("swrot a=%s ref=(%d,%d) sw=(%d,%d) sw_cyc=%d %s\n",
               angle_labels[i], expected_x, expected_y, sw_out_x, sw_out_y,
               sw_cycles, ok ? "PASS" : "FAIL");
    }
    printf("%d/%d SWROT_PASS\n", pass, NUM_ANGLES);

    uart_write_flush();
    return 0;
}
