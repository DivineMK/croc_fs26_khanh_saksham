#include "fft.h"
#include "cordic.h"

#define Q16_ONE 65536

int32_t mul_fixed(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * b) >> 16);
}

void fft(int32_t data_re[], int32_t data_im[], unsigned int N) {
    fft_with(data_re, data_im, N, sw_sincos);
}

void fft_with(int32_t data_re[], int32_t data_im[], unsigned int N, sincos_fn sincos) {
    rearrange(data_re, data_im, N);
    compute_with(data_re, data_im, N, sincos);
}

// Bit-reversal permutation: reorders data so the iterative FFT can work in-place.
// For each index i, find its bit-reversed counterpart j; if j > i, swap data[i] and data[j].
void rearrange(int32_t data_re[], int32_t data_im[], unsigned int N) {
    unsigned int target = 0;
    for (unsigned int position = 0; position < N; position++) {
        if (target > position) {
            int32_t temp_re = data_re[target];
            int32_t temp_im = data_im[target];
            data_re[target] = data_re[position];
            data_im[target] = data_im[position];
            data_re[position] = temp_re;
            data_im[position] = temp_im;
        }
        // The carry-propagation trick below computes the next bit-reversed index from the current one
        // in O(1) amortized (each bit flips exactly once across the full loop).
        // Advance to next bit-reversed index: find rightmost 0-bit, set it, clear lower bits.
        // E.g. 0111 -> 1000 (carry propagates through three 1-bits).
        unsigned int mask = N;
        while (target & (mask >>= 1))
            target &= ~mask;
        target |= mask;
    }
}

void compute(int32_t data_re[], int32_t data_im[], unsigned int N) {
    compute_with(data_re, data_im, N, sw_sincos);
}

void compute_with(int32_t data_re[], int32_t data_im[], unsigned int N, sincos_fn sincos) {
    for (unsigned int step = 1; step < N; step <<= 1) {
        unsigned int jump = step << 1;
        int32_t twiddle_re = Q16_ONE;
        int32_t twiddle_im = 0;

        // CORDIC_PI / step is exact since step is always a power of two
        uint32_t angle_step = CORDIC_PI / step;
        uint32_t angle = angle_step;

        for (unsigned int group = 0; group < step; group++) {
            for (unsigned int pair = group; pair < N; pair += jump) {
                unsigned int match = pair + step;

                int32_t prod_re = mul_fixed(twiddle_re, data_re[match])
                                - mul_fixed(twiddle_im, data_im[match]);
                int32_t prod_im = mul_fixed(twiddle_im, data_re[match])
                                + mul_fixed(twiddle_re, data_im[match]);

                data_re[match] = data_re[pair] - prod_re;
                data_im[match] = data_im[pair] - prod_im;
                data_re[pair] += prod_re;
                data_im[pair] += prod_im;
            }

            if (group + 1 == step)
                continue;

            int32_t s, c;
            sincos(angle, &s, &c);
            twiddle_re = c;
            twiddle_im = -s;
            angle += angle_step;
        }
    }
}

int32_t kc(int32_t x) {
    return (int32_t)(((int64_t)x * CORDIC_K) >> 16);
}

void fft_rotate(int32_t data_re[], int32_t data_im[], unsigned int N, rotate_fn rotate) {
    rearrange(data_re, data_im, N);
    compute_with_rotate(data_re, data_im, N, rotate);
}

void compute_with_rotate(int32_t data_re[], int32_t data_im[], unsigned int N, rotate_fn rotate) {
    for (unsigned int step = 1; step < N; step <<= 1) {
        unsigned int jump = step << 1;

        uint32_t angle_step = CORDIC_PI / step;
        uint32_t angle = 0;

        for (unsigned int group = 0; group < step; group++) {
            for (unsigned int pair = group; pair < N; pair += jump) {
                unsigned int match = pair + step;

                int32_t rot_re, rot_im;
                rotate(data_re[match], data_im[match], (uint32_t)(-(int32_t)angle), &rot_re, &rot_im);
                rot_re = kc(rot_re);
                rot_im = kc(rot_im);

                data_re[match] = data_re[pair] - rot_re;
                data_im[match] = data_im[pair] - rot_im;
                data_re[pair] += rot_re;
                data_im[pair] += rot_im;
            }

            if (group + 1 == step)
                continue;

            angle += angle_step;
        }
    }
}
