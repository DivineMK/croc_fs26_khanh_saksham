/*
 * test_pll.c -- 1-phase digital PLL using CORDIC sincos.
 *
 * Demonstrates a real-world embedded application of CORDIC:
 *   - NCO (Numerically Controlled Oscillator) generates sin/cos
 *   - Phase detector tracks a reference sine wave
 *   - PI loop filter drives frequency/phase estimate to lock
 *
 * Compares sw_sincos vs hw_sincos for the NCO hot path.
 */
#include "cordic.h"
#include "fft.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define REF_PERIOD       64
#define REF_LUT_BITS     6
#define REF_LUT_SIZE     64
#define PLL_ITERATIONS   128
#define LOCK_THRESHOLD   4096
#define LOCK_COUNT       8

/* PI gains — account for PD gain of 0.5 (sin*cos = 0.5*sin(2w)) */
#define KP               11126 /* Q15.16 ~= 0.17 */
#define KI               236   /* Q15.16 ~= 0.0036 */

#define NOMINAL_FREQ_CMD ((uint32_t)(0x100000000ULL / REF_PERIOD) >> 16)
#define FREQ_LOCK_THRESH 256

static int32_t ref_sin_lut[REF_LUT_SIZE];

static void gen_reference(void) {
    for (int i = 0; i < REF_LUT_SIZE; i++) {
        uint32_t angle = (uint32_t)i << (32 - REF_LUT_BITS);
        int32_t s, c;
        sw_sincos(angle, &s, &c);
        ref_sin_lut[i] = s;
    }
}

static inline int32_t mul_q16(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * b) >> 16);
}

typedef struct {
    uint32_t total_cycles;
    int lock_iter;
    int32_t final_freq_cmd;
    int locked;
} pll_result_t;

static void run_pll(sincos_fn sincos_func, pll_result_t *result) {
    int32_t integral  = 0;
    uint32_t phase    = 0;
    int32_t cos_est   = 65536;
    int lock_streak   = 0;
    result->locked    = 0;
    result->lock_iter = -1;

    uint32_t start    = get_mcycle();

    for (int i = 0; i < PLL_ITERATIONS; i++) {
        int32_t ref   = ref_sin_lut[i & (REF_LUT_SIZE - 1)];

        /* PD: ref * cos_est, shift by 15 (not 16) to compensate for
         * the 0.5 gain of the sin*cos product */
        int32_t error = (int32_t)((((int64_t)ref * cos_est) >> 15));

        int32_t prop  = mul_q16(KP, error);
        integral += mul_q16(KI, error);
        int32_t freq_cmd = prop + integral;

        phase += (uint32_t)(freq_cmd << 16);
        int32_t sin_est;
        sincos_func(phase, &sin_est, &cos_est);

        int32_t abs_err = error >= 0 ? error : -error;
        if (abs_err < LOCK_THRESHOLD) {
            lock_streak++;
            if (lock_streak >= LOCK_COUNT && !result->locked) {
                int32_t freq_err = freq_cmd - (int32_t)NOMINAL_FREQ_CMD;
                if (freq_err < 0) freq_err = -freq_err;
                if (freq_err < FREQ_LOCK_THRESH) {
                    result->locked    = 1;
                    result->lock_iter = i;
                }
            }
        } else {
            lock_streak = 0;
        }
    }

    uint32_t end           = get_mcycle();
    result->total_cycles   = end - start;
    result->final_freq_cmd = integral;
}

int main(void) {
    //uart_init();
    cordic_set_drcg(1);
    cordic_set_precision(CORDIC_PREC_FULL);
    gen_reference();

    int32_t sin_out, cos_out;
    uint32_t t0, t1;

    // pll_result_t sw_res;
    // run_pll(sw_sincos, &sw_res);
    //printf("sw:lock=%d tot=%d avg=%d freq=%d\n",
    //       sw_res.lock_iter, sw_res.total_cycles,
    //       sw_res.total_cycles / PLL_ITERATIONS,
    //       sw_res.final_freq_cmd);

    pll_result_t hw_res;
    run_pll(hw_sincos, &hw_res);
    //printf("hw:lock=%d tot=%d avg=%d freq=%d\n",
    //       hw_res.lock_iter, hw_res.total_cycles,
    //       hw_res.total_cycles / PLL_ITERATIONS,
    //       hw_res.final_freq_cmd);

    //uint32_t speedup_x100 = (sw_res.total_cycles * 100) / hw_res.total_cycles;
    //printf("speedup=%d.%dx locked=%d,%d\n",
    //       speedup_x100 / 100, speedup_x100 % 100,
    //       sw_res.locked, hw_res.locked);

    //uart_write_flush();
    return 0;
}
