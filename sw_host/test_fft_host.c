#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <x86intrin.h>
#include "../sw/lib/inc/fft.h"

#define Q16_ONE 65536
#define FTOQ(x) ((int32_t)((x) * (float)Q16_ONE))
#define QTOF(x) ((float)(x) / (float)Q16_ONE)

static int compare_arrays(const int32_t x[], const int32_t y[], unsigned int N, int rel_tol_pct, int32_t abs_floor) {
    int result = 1;
    for (unsigned int i = 0; i < N; i++) {
        int32_t diff = x[i] - y[i];
        if (diff < 0) diff = -diff;
        int32_t ref = y[i];
        if (ref < 0) ref = -ref;
        int32_t rel_tol = (int32_t)((int64_t)ref * rel_tol_pct / 100);
        int32_t tol     = rel_tol > abs_floor ? rel_tol : abs_floor;
        if (diff > tol) result = 0;
    }
    return result;
}

// Floating-point reference FFT using cos/sin twiddles
static void fft_float(double *re, double *im, int n) {
    // Bit-reversal permutation
    for (int i = 0, j = 0; i < n; i++) {
        if (i < j) {
            double t = re[i];
            re[i]    = re[j];
            re[j]    = t;
            t        = im[i];
            im[i]    = im[j];
            im[j]    = t;
        }
        int m = n >> 1;
        while (m >= 1 && j >= m) {
            j -= m;
            m >>= 1;
        }
        j += m;
    }
    for (int step = 1; step < n; step <<= 1) {
        int jump          = step << 1;
        double angle_step = 3.14159265358979323846 / step;
        for (int group = 0; group < step; group++) {
            double w_re = cos(-angle_step * group);
            double w_im = sin(-angle_step * group);
            for (int pair = group; pair < n; pair += jump) {
                int match   = pair + step;
                double t_re = w_re * re[match] - w_im * im[match];
                double t_im = w_re * im[match] + w_im * re[match];
                re[match]   = re[pair] - t_re;
                im[match]   = im[pair] - t_im;
                re[pair] += t_re;
                im[pair] += t_im;
            }
        }
    }
}

static void gen_signal(int32_t *re, int32_t *im, int n) {
    for (int i = 0; i < n; i++) {
        int32_t val = 0;
        if (i % 3 == 0) val += Q16_ONE;
        if (i % 5 == 0) val -= Q16_ONE;
        if (i % 7 == 0) val += Q16_ONE;
        re[i] = val;
        im[i] = 0;
    }
}

static void compute_errors(const int32_t *fp_re, const int32_t *fp_im, const double *fl_re, const double *fl_im, int n,
                           const char *label) {
    double max_err_re = 0, max_err_im = 0;
    double rms_err_re = 0, rms_err_im = 0;
    int max_bin = 0;

    for (int i = 0; i < n; i++) {
        double err_re = fabs(QTOF(fp_re[i]) - fl_re[i]);
        double err_im = fabs(QTOF(fp_im[i]) - fl_im[i]);
        rms_err_re += err_re * err_re;
        rms_err_im += err_im * err_im;
        if (err_re > max_err_re) {
            max_err_re = err_re;
            max_bin    = i;
        }
        if (err_im > max_err_im) {
            max_err_im = err_im;
        }
    }
    rms_err_re = sqrt(rms_err_re / n);
    rms_err_im = sqrt(rms_err_im / n);

    printf("  %s\n", label);
    printf("    Max |error|:  re=%.6f  im=%.6f  (Q16 units: re=%d im=%d at bin %d)\n", max_err_re, max_err_im,
           fp_re[max_bin] - (int32_t)(fl_re[max_bin] * Q16_ONE), fp_im[max_bin] - (int32_t)(fl_im[max_bin] * Q16_ONE),
           max_bin);
    printf("    RMS |error|:  re=%.6f  im=%.6f  (Q16 units: re=%.1f im=%.1f)\n", rms_err_re, rms_err_im,
           sqrt(rms_err_re * rms_err_re) * Q16_ONE, sqrt(rms_err_im * rms_err_im) * Q16_ONE);
}

int main(void) {
    printf("=== Fixed-point vs Float FFT Error Analysis (N=128) ===\n\n");

    // Test signal: same as test_fft.c
    int32_t re[128], im[128];
    gen_signal(re, im, 128);

    // Float reference
    double fl_re[128], fl_im[128];
    for (int i = 0; i < 128; i++) {
        fl_re[i] = QTOF(re[i]);
        fl_im[i] = QTOF(im[i]);
    }
    fft_float(fl_re, fl_im, 128);

    // Fixed-point: fft() uses cordic_sincos internally
    int32_t fp_re[128], fp_im[128];
    for (int i = 0; i < 128; i++) {
        fp_re[i] = re[i];
        fp_im[i] = im[i];
    }
    fft(fp_re, fp_im, 128);
    compute_errors(fp_re, fp_im, fl_re, fl_im, 128, "cordic_sincos vs double-precision:");

    return 0;
}
