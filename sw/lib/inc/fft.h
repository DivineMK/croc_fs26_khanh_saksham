#pragma once
#include <stdint.h>

typedef void (*sincos_fn)(uint32_t angle, int32_t *sin, int32_t *cos);
typedef void (*rotate_fn)(int32_t x, int32_t y, uint32_t angle, int32_t *x_out, int32_t *y_out);

void fft(int32_t data_re[], int32_t data_im[], unsigned int N);
void fft_with(int32_t data_re[], int32_t data_im[], unsigned int N, sincos_fn sincos);
void fft_rotate(int32_t data_re[], int32_t data_im[], unsigned int N, rotate_fn rotate);
void rearrange(int32_t data_re[], int32_t data_im[], unsigned int N);
void compute(int32_t data_re[], int32_t data_im[], unsigned int N);
void compute_with(int32_t data_re[], int32_t data_im[], unsigned int N, sincos_fn sincos);
void compute_with_rotate(int32_t data_re[], int32_t data_im[], unsigned int N, rotate_fn rotate);
int32_t mul_fixed(int32_t a, int32_t b);
int32_t kc(int32_t x);
