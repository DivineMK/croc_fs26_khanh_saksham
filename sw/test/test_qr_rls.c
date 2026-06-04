#include "qr_rls.h"
#include "cordic.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define N       4
#define M       32
#define LAMBDA  64225   // 0.98 in Q15.16
#define DELTA   655     // 0.01 in Q15.16 (diagonal loading)

static int32_t R[N * N], p[N];
static int32_t R_ref[N * N], p_ref[N];
static int32_t x[N], x_history[M];

static void fill_array(int32_t *dst, int32_t value, int count) {
    for (int i = 0; i < count; i++) dst[i] = value;
}

static void save_reference(void) {
    for (unsigned i = 0; i < N * N; i++) R_ref[i] = R[i];
    for (unsigned i = 0; i < N; i++) p_ref[i] = p[i];
}

static int check_match(const int32_t *ref, const int32_t *actual, unsigned count) {
    return cmp_rel(ref, actual, count, 3, 500);
}

static void gen_test_signal(void) {
    for (int i = 0; i < M; i++) {
        int32_t val = 0;
        val += (int32_t)(16384 * ((i % 17) < 8 ? 1 : -1));
        val += (int32_t)(8192  * ((i % 7)  < 3 ? 1 : -1));
        x_history[i] = val;
    }
}

int main(void) {
    uart_init();
    uint32_t start, end;
    uint32_t baseline_cycles;

    cordic_set_precision(CORDIC_PREC_FULL);

    // Generate input signal
    gen_test_signal();

    // ---- Baseline: SW vectoring + SW rotation ----
    qr_rls_init(R, p, N, DELTA);
    start = get_mcycle();
    for (unsigned n = 0; n < M; n++) {
        // Form input vector: [x(n), x(n-1), ..., x(n-N+1)]
        for (unsigned i = 0; i < N; i++) {
            x[i] = (n >= i) ? x_history[n - i] : 0;
        }
        int32_t d = x_history[n];  // desired = input (system identification of identity)
        qr_rls_update(R, p, x, d, N, LAMBDA, sw_vector, sw_rotate);
    }
    end = get_mcycle();
    baseline_cycles = end - start;
    // save_reference();
    printf("baseline (sw+sw):  %d cycles\n", baseline_cycles);

     // ---- HW vector + HW rotation ----
     qr_rls_init(R, p, N, DELTA);
     start = get_mcycle();
     for (unsigned n = 0; n < M; n++) {
         for (unsigned i = 0; i < N; i++) {
             x[i] = (n >= i) ? x_history[n - i] : 0;
         }
         int32_t d = x_history[n];
         qr_rls_update(R, p, x, d, N, LAMBDA, hw_vector, hw_rotate);
     }
     end = get_mcycle();
     int sw_match = check_match(R_ref, R, N * N) && check_match(p_ref, p, N);
     printf("hw+hw:            %d cycles  %s\n", end - start, sw_match ? "PASS" : "FAIL");

     // ---- HW vector + SW rotation ----
     qr_rls_init(R, p, N, DELTA);
     start = get_mcycle();
     for (unsigned n = 0; n < M; n++) {
         for (unsigned i = 0; i < N; i++) {
             x[i] = (n >= i) ? x_history[n - i] : 0;
         }
         int32_t d = x_history[n];
         qr_rls_update(R, p, x, d, N, LAMBDA, hw_vector, sw_rotate);
     }
     end = get_mcycle();
     int hwvec_match = check_match(R_ref, R, N * N) && check_match(p_ref, p, N);
     printf("hw_vec+sw_rot:    %d cycles  %s\n", end - start, hwvec_match ? "PASS" : "FAIL");

     // ---- SW vector + HW rotation ----
     qr_rls_init(R, p, N, DELTA);
     start = get_mcycle();
     for (unsigned n = 0; n < M; n++) {
         for (unsigned i = 0; i < N; i++) {
             x[i] = (n >= i) ? x_history[n - i] : 0;
         }
         int32_t d = x_history[n];
         qr_rls_update(R, p, x, d, N, LAMBDA, sw_vector, hw_rotate);
     }
     end = get_mcycle();
     int hwrot_match = check_match(R_ref, R, N * N) && check_match(p_ref, p, N);
     printf("sw_vec+hw_rot:    %d cycles  %s\n", end - start, hwrot_match ? "PASS" : "FAIL");

    uart_write_flush();
    return 0;
}
