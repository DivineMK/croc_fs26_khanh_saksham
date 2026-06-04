#include "fft.h"
#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define Q16_ONE 65536
#define N       128
#define SINCOS_CALLS 120
#define ROTATE_CALLS 448

static int32_t re[N], im[N];
static int32_t ref_re[N], ref_im[N];

static void gen_signal(void) {
    for (int i = 0; i < N; i++) {
        int32_t val = 0;
        if (i % 3 == 0) val += Q16_ONE;
        if (i % 5 == 0) val -= Q16_ONE;
        if (i % 7 == 0) val += Q16_ONE;
        re[i] = val;
        im[i] = 0;
    }
}

static int check_match(int count) {
    return cmp_rel(ref_re, re, count, 3, 200) &&
           cmp_rel(ref_im, im, count, 3, 200);
}

int main(void) {
    uart_init();
    uint32_t start, end;

    cordic_set_precision(CORDIC_PREC_FULL);

    // Micro-benchmarks: per-call cycle cost
    #define B 100
    start = get_mcycle();
    for (unsigned i = 0; i < B; i++) mul_fixed(12345, 54321);
    end = get_mcycle();
    uint32_t mul_fixed_cyc = (end - start) / B;

    start = get_mcycle();
    for (unsigned i = 0; i < B; i++) kc(12345);
    end = get_mcycle();
    uint32_t kc_cyc = (end - start) / B;

    int32_t sw_bench_sin, sw_bench_cos, hw_bench_sin, hw_bench_cos;
    int32_t hw_bench_x, hw_bench_y, sw_bench_x, sw_bench_y;

    start=get_mcycle(); sw_sincos(0x20000000,&sw_bench_sin,&sw_bench_cos); end=get_mcycle();
    uint32_t sw_sincos_cyc=end-start;

    start=get_mcycle(); hw_sincos(0x20000000,&hw_bench_sin,&hw_bench_cos); end=get_mcycle();
    uint32_t hw_sincos_cyc=end-start;

    start=get_mcycle(); hw_rotate(65536,0,0x20000000,&hw_bench_x,&hw_bench_y); end=get_mcycle();
    uint32_t hw_rotate_cyc=end-start;

    start=get_mcycle(); sw_rotate(65536,0,0x20000000,&sw_bench_x,&sw_bench_y); end=get_mcycle();
    uint32_t sw_rotate_cyc=end-start;

    printf("bench:mul_fixed=%d kc=%d sw_sincos=%d hw_sincos=%d hw_rotate=%d sw_rotate=%d\n",
           mul_fixed_cyc, kc_cyc, sw_sincos_cyc, hw_sincos_cyc, hw_rotate_cyc, sw_rotate_cyc);
    printf("bench_vals:sw=%d,%d hw=%d,%d hwrot=%d,%d swrot=%d,%d\n",
           sw_bench_sin,sw_bench_cos,hw_bench_sin,hw_bench_cos,
           hw_bench_x,hw_bench_y,sw_bench_x,sw_bench_y);

    // Rearrange
    gen_signal();
    start=get_mcycle(); rearrange(re,im,N); end=get_mcycle();
    uint32_t rearrange_cyc=end-start;
    printf("rearrange: %d\n", rearrange_cyc);

    // FFT baseline: sw_sincos (reference)
    gen_signal();
    start=get_mcycle(); fft(re,im,N); end=get_mcycle();
    for(int i=0;i<N;i++){ref_re[i]=re[i];ref_im[i]=im[i];}
    uint32_t fft_sw_sincos=end-start;
    printf("fft:sw_sincos=%d ok=%d\n", fft_sw_sincos, check_match(N));

    // // FFT with hw_sincos
    // gen_signal();
    // start=get_mcycle(); fft_with(re,im,N,hw_sincos); end=get_mcycle();
    // uint32_t fft_hw_sincos=end-start;
    // printf("fft:hw_sincos=%d ok=%d\n", fft_hw_sincos, check_match(N));
    //
    // // FFT with hw_rotate
    // gen_signal();
    // start=get_mcycle(); fft_rotate(re,im,N,hw_rotate); end=get_mcycle();
    // uint32_t fft_hw_rotate=end-start;
    // printf("fft:hw_rotate=%d ok=%d\n", fft_hw_rotate, check_match(N));
    //
    // // FFT with sw_rotate
    // gen_signal();
    // start=get_mcycle(); fft_rotate(re,im,N,sw_rotate); end=get_mcycle();
    // uint32_t fft_sw_rotate=end-start;
    // printf("fft:sw_rotate=%d ok=%d\n", fft_sw_rotate, check_match(N));
    //
    // // Per-butterfly cost from bench data
    // uint32_t sincos_bf=sw_sincos_cyc+4*mul_fixed_cyc;
    // uint32_t hw_sincos_bf=hw_sincos_cyc+4*mul_fixed_cyc;
    // uint32_t sw_rotate_bf=sw_rotate_cyc+kc_cyc;
    // uint32_t hw_rotate_bf=hw_rotate_cyc+kc_cyc;
    //
    // printf("bf:sw_sincos=%d hw_sincos=%d hw_rotate=%d sw_rotate=%d\n",
    //        sincos_bf, hw_sincos_bf, hw_rotate_bf, sw_rotate_bf);
    // printf("calls:sincos=%d rotate=%d\n", SINCOS_CALLS, ROTATE_CALLS);
    // printf("hw_rotate vs hw_sincos: %s\n", hw_rotate_bf<hw_sincos_bf?"wins":"loses");
    // printf("sw_rotate vs sw_sincos: %s\n", sw_rotate_bf<sincos_bf?"wins":"loses");

    uart_write_flush();
    return 0;
}
