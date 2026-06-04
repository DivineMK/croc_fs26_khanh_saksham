/*
 * qr_rls.c -- QR-RLS adaptive filter via Givens rotations.
 *
 * QR-RLS (Recursive Least Squares) estimates an unknown FIR filter w of
 * length N by factorising the input autocorrelation matrix R = X^T X using
 * Givens rotations applied to an augmented vector [x; d]. Each new sample
 * (d, x) is incorporated with O(N^2) CORDIC operations (no division,
 * no explicit matrix inversion).
 *
 * Data format: Q15.16 fixed-point (16 fractional bits).
 * CORDIC operations (vectoring + rotation) replace all multiply/divide.
 * Compensation gain K ~ 0.6073 compensates for CORDIC magnitude
 * distortion (cos(atan(2^-i)) product).
 *
 * Pluggable CORDIC functions allow hw_vector/hw_rotate for hardware
 * acceleration or sw_vector/sw_rotate for software fallback.
 */
#include "qr_rls.h"
#include "cordic.h"

#define Q16_ONE 65536

/*
 * kc -- CORDIC K-gain compensation.
 * After vectoring/rotation, output = K * true_value where K = prod(cos(atan(2^-i))).
 * K ~ 0.6073 = 39797/65536 in Q15.16.
 */
static inline int32_t kc(int32_t x) {
    return (int32_t)(((int64_t)x * CORDIC_K) >> 16);
}

/*
 * mul_q16 -- Q15.16 fixed-point multiply.
 */
static inline int32_t mul_q16(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * b) >> 16);
}

/*
 * qr_rls_init -- Initialise R = delta * I, p = 0.
 * Diagonal loading (delta) ensures R is positive definite at startup,
 * preventing division-by-zero in the first rotation. Typical delta ~ 0.01.
 */
void qr_rls_init(int32_t *R, int32_t *p, unsigned N, int32_t delta_q16) {
    for (unsigned i = 0; i < N; i++) {
        p[i] = 0;
        for (unsigned j = 0; j < N; j++) {
            R[i * N + j] = (i == j) ? delta_q16 : 0;
        }
    }
}

/*
 * qr_rls_update -- Incorporate new sample (d, x) into QR factorisation.
 *
 * Algorithm:
 *   1. Scale R and p by sqrt(lambda) to forget old data exponentially.
 *   2. Append x and d to form augmented vector [R; p] | [x; d].
 *   3. For each column i = 0..N-1:
 *      a. Vectoring mode: find angle theta_i that zeros x_aug[i].
 *      b. Set R[i,i] = kc(magnitude).
 *      c. Rotation mode: apply -theta_i to remaining columns and p.
 *      d. Rotate the "error" term x_aug[N] (holds d or residual).
 *   After N rotations: R is upper triangular, p contains the
 *   converted gain vector for back-substitution.
 */
void qr_rls_update(int32_t *R, int32_t *p, const int32_t *x, int32_t d,
                    unsigned N, int32_t lambda_q16,
                    vector_fn vector_fn_p, rotate_fn rotate_fn_p) {
    // Step 1: Scale R and p by sqrt(lambda)
    // sqrt(lambda) approximated via Newton's method: sqrt(x) ~ (x+1)/2,
    // with one refinement step for better accuracy when lambda ~ 0.98.
    int32_t sqrt_lambda_q16 = (lambda_q16 + Q16_ONE) >> 1;
    if (lambda_q16 < Q16_ONE) {
        // Second Newton step: sqrt(x) ~ (x/a + a) / 2 where a = current estimate
        sqrt_lambda_q16 = (mul_q16(lambda_q16,
                    (int32_t)((uint32_t)Q16_ONE / (sqrt_lambda_q16 >> 16 < 1 ? 1 : sqrt_lambda_q16 >> 16)))
                + sqrt_lambda_q16) >> 1;
    }

    // Scale R by sqrt(lambda) -- only upper triangle needed
    for (unsigned i = 0; i < N; i++) {
        for (unsigned j = i; j < N; j++) {
            R[i * N + j] = mul_q16(R[i * N + j], sqrt_lambda_q16);
        }
    }
    // Scale p by sqrt(lambda)
    for (unsigned i = 0; i < N; i++) {
        p[i] = mul_q16(p[i], sqrt_lambda_q16);
    }

    // Step 2: Givens rotations on augmented vector [x; d]
    // x_aug = [x[0], ..., x[N-1], d]. After N vectoring+rotation pairs,
    // x_aug[0..N-1] become zero (absorbed into R diagonal), and x_aug[N]
    // holds the residual (a priori error).
    int32_t x_aug[N + 1];
    for (unsigned i = 0; i < N; i++) x_aug[i] = x[i];
    x_aug[N] = d;

    for (unsigned i = 0; i < N; i++) {
        // Vectoring: find angle theta_i that rotates [R[i,i], x_aug[i]]
        // to [magnitude, 0]. This zeros out x_aug[i].
        int32_t mag, angle;
        vector_fn_p(R[i * N + i], x_aug[i], &mag, &angle);

        // Update diagonal with K-compensated magnitude
        R[i * N + i] = kc(mag);

        // Rotation: apply -theta_i to remaining columns and p.
        // Negate because vectoring gives +theta, rotation needs -theta
        // to complete the Givens transformation G_i = [cos -sin; sin cos].
        uint32_t neg_angle = (uint32_t)(-(int32_t)angle);

        // Apply Givens rotation to R[i, i+1..N-1] and x_aug[i+1..N-1]
        for (unsigned j = i + 1; j < N; j++) {
            int32_t r_new, x_new;
            rotate_fn_p(R[i * N + j], x_aug[j], neg_angle, &r_new, &x_new);
            R[i * N + j] = kc(r_new);
            x_aug[j] = kc(x_new);
        }

        // Rotate p[i] and the error term x_aug[N]
        int32_t p_new, g_new;
        rotate_fn_p(p[i], x_aug[N], neg_angle, &p_new, &g_new);
        p[i] = kc(p_new);
        x_aug[N] = kc(g_new);
    }
}
