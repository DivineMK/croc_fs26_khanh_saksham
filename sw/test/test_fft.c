#include "fft.h"
#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define Q16_ONE 65536
#define N       128

static int32_t re[N], im[N];
static int32_t ref_re[N], ref_im[N];

/** Fill array with a constant value. */
static void fill_array(int32_t *dst, int32_t value, int count) {
    for (int i = 0; i < count; i++) dst[i] = value;
}

/** Save current FFT output as reference for comparison. */
static void save_reference(int count) {
    for (int i = 0; i < count; i++) {
        ref_re[i] = re[i];
        ref_im[i] = im[i];
    }
}

/** Check if current FFT output matches the saved reference. */
static int check_match(int count) {
    return cmp_rel(ref_re, re, count, 3, 200) && cmp_rel(ref_im, im, count, 3, 200);
}
 /**
  * Generate a diverse test signal: sum of rectangular waves at
  * coprime periods (3, 5, 7). This produces energy across many
  * non-trivial bins, unlike DC (bin 0) or alternating (bin N/2).
  */
static void gen_signal(void) {
    for (int i = 0; i < N; i++) {
        // +Q16 at multiples of 3, -Q16 at multiples of 5, +Q16 at multiples of 7
        int32_t val = 0;
        if (i % 3 == 0) val += Q16_ONE;
        if (i % 5 == 0) val -= Q16_ONE;
        if (i % 7 == 0) val += Q16_ONE;
        re[i] = val;
        im[i] = 0;
    }
}

int main(void) {
    uart_init();
    uint32_t start, end;
    uint32_t baseline_cycles;

    // DRCG workaround: precision_q resets to 0 on gated clock domain.
    cordic_set_precision(CORDIC_PREC_FULL);

    // Baseline: SW sincos FFT
    gen_signal();
    start = get_mcycle();
    fft(re, im, N);
    end             = get_mcycle();
    baseline_cycles = end - start;
    save_reference(N);
    printf("baseline:  %d cycles\n", baseline_cycles);

    // hw_sincos: standard twiddle, HW sincos
    gen_signal();
    start = get_mcycle();
    fft_with(re, im, N, hw_sincos);
    end = get_mcycle();
    printf("hw_sincos: %d cycles  %s\n", end - start, check_match(N) ? "PASS" : "FAIL");

    // hw_rotate: rotation butterfly, HW rotate
    gen_signal();
    start = get_mcycle();
    fft_rotate(re, im, N, hw_rotate);
    end = get_mcycle();
    printf("hw_rotate: %d cycles  %s\n", end - start, check_match(N) ? "PASS" : "FAIL");

    // sw_rotate: rotation butterfly, SW rotate
    gen_signal();
    start = get_mcycle();
    fft_rotate(re, im, N, sw_rotate);
    end = get_mcycle();
    printf("sw_rotate: %d cycles  %s\n", end - start, check_match(N) ? "PASS" : "FAIL");

    uart_write_flush();
    return 0;
}
