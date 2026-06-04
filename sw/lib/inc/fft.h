// file fft.h
#ifndef EXAMPLE_FFT
#define EXAMPLE_FFT

#include <stdint.h>

// The arrays for the fft will be computed in place
// and thus your array will have the fft result
// written over your original data.
// We require an array of real and imaginary floats
// where they are both of length N
void fft(float data_re[], float data_im[], const unsigned int N);

// helper functions called by the fft
// data will first be rearranged then computed
// an array of  {1, 2, 3, 4, 5, 6, 7, 8} will be
// rearranged to {1, 5, 3, 7, 2, 6, 4, 8}
void rearrange(float data_re[], float data_im[], const unsigned int N);

void compute(float data_re[], float data_im[], const unsigned int N);

int32_t compare_arrays(const float x[], const float y[], const unsigned int32_t N, const float eps);

void print_arr(const float data[], const unsigned int32_t N);

void print_test_result(int32_t tc_re, int32_t tc_im, int32_t tc_num, int32_t cycles);

#endif
