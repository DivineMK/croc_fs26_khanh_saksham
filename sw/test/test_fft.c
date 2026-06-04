#include <stdio.h>
#include <math.h>
#include "fft.h"



// We will run 4 test cases to ensure our FFT data is correct
int32_t main(int32_t argc, char **argv) {
    int32_t i; // loop iterator

    // Test Case 0 - Rearranging
    float data0_re[8]     = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    float expected0_re[8] = {1.0, 5.0, 3.0, 7.0, 2.0, 6.0, 4.0, 8.0};
    float data0_im[8]     = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0};
    float expected0_im[8] = {1.0, 5.0, 3.0, 7.0, 2.0, 6.0, 4.0, 8.0};
    rearrange(data0_re, data0_im, 8);
    int32_t tc0_re = compare_arrays(data0_re, expected0_re, 8, 0.01);
    int32_t tc0_im = compare_arrays(data0_im, expected0_im, 8, 0.01);
    print_test_result(tc0_re, tc0_im, 0);

    // Test Case 1
    float data1_re[8]     = {0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0};
    float data1_im[8]     = {7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0};
    float expected1_re[8] = {28.0, 5.656, 0.0, -2.343, -4.0, -5.656, -8.0, -13.656};
    float expected1_im[8] = {28.0, 13.656, 8.0, 5.656, 4.0, 2.343, 0.0, -5.656};

    int32_t t0, t1;
    t0 = get_mcycle();
    fft(data1_re, data1_im, 8);
    t1             = get_mcycle();
    int32_t cycles = t1 - t0;

    int32_t tc1_re = compare_arrays(data1_re, expected1_re, 8, 0.01);
    int32_t tc1_im = compare_arrays(data1_im, expected1_im, 8, 0.01);
    print_test_result(tc1_re, tc1_im, 1, cycles);

    // Test Case 2
    float data2_re[8]     = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
    float data2_im[8]     = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0};
    float expected2_re[8] = {8.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    float expected2_im[8] = {8.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    fft(data2_re, data2_im, 8);
    int32_t tc2_re = compare_arrays(data2_re, expected2_re, 8, 0.01);
    int32_t tc2_im = compare_arrays(data2_im, expected2_im, 8, 0.01);
    print_test_result(tc2_re, tc2_im, 2);

    // Test Case 3
    float data3_re[8]     = {1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0};
    float data3_im[8]     = {-1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0};
    float expected3_re[8] = {0.0, 0.0, 0.0, 0.0, 8.0, 0.0, 0.0, 0.0};
    float expected3_im[8] = {0.0, 0.0, 0.0, 0.0, -8.0, 0.0, 0.0, 0.0};
    fft(data3_re, data3_im, 8);
    int32_t tc3_re = compare_arrays(data3_re, expected3_re, 8, 0.01);
    int32_t tc3_im = compare_arrays(data3_im, expected3_im, 8, 0.01);
    print_test_result(tc3_re, tc3_im, 3);

    // Test Case 4
    float data4_re[4]     = {1.0, 2.0, 3.0, 4.0};
    float data4_im[4]     = {0.0, 0.0, 0.0, 0.0};
    float expected4_re[4] = {10.0, -2.0, -2.0, -2.0};
    float expected4_im[4] = {0.0, 2.0, 0.0, -2.0};
    fft(data4_re, data4_im, 4);
    int32_t tc4_re = compare_arrays(data4_re, expected4_re, 4, 0.01);
    int32_t tc4_im = compare_arrays(data4_im, expected4_im, 4, 0.01);
    print_test_result(tc4_re, tc4_im, 4);
}

void print_test_result(int32_t tc_re, int32_t tc_im, int32_t tc_num, int32_t cycles) {
    int32_t res = tc_re + tc_im;
    if (res == 2) {
        printf("Test Case %d: Passed\n", tc_num);
        printf("Cycles for Op: %d\n", cycles);
    } else {
        printf("Test Case %d: Failed\n", tc_num);
        printf("Cycles for Op: %d\n", cycles);
    }
}

int32_t compare_arrays(const float x[], const float y[], const unsigned int32_t N, const float eps) {
    int32_t result = 1;
    for (unsigned int32_t i = 0; i < N; i++) {
        if (fabs(x[i] - y[i]) > eps) {
            result = 0;
        }
    }

    if (result == 0) {
        printf("Expected: ");
        print_arr(y, N);
        printf("Got     : ");
        print_arr(x, N);
    }

    return 1;
}

void print_arr(const float data[], const unsigned int32_t N) {
    printf("{");
    for (unsigned int32_t i = 0; i < N - 1; i++) printf("%.3f, ", data[i]);
    printf("%.3f}\n", data[N - 1]);
}
