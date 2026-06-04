/*
 * qr_rls.h -- QR-RLS adaptive filter using Givens rotations.
 *
 * Recursive Least Squares adaptive filter that uses QR decomposition
 * via CORDIC Givens rotations (no division, no matrix inversion).
 * All arithmetic in Q15.16 fixed-point.
 *
 * Usage:
 *   1. qr_rls_init(R, p, N, delta) -- zero state with diagonal loading
 *   2. For each sample: qr_rls_update(R, p, x, d, N, lambda, vfn, rfn)
 *   3. Access R (upper triangular) and p (gain vector) for adaptation
 *
 * Pluggable CORDIC functions (vector_fn, rotate_fn) allow swapping
 * between hardware (hw_vector/hw_rotate) and software (sw_vector/sw_rotate)
 * implementations without changing the algorithm.
 */
#pragma once
#include <stdint.h>

typedef void (*vector_fn)(int32_t x, int32_t y, int32_t *mag, int32_t *phase);
typedef void (*rotate_fn)(int32_t x, int32_t y, uint32_t angle, int32_t *x_out, int32_t *y_out);

/**
  * @brief Initialize QR-RLS state: R = delta * I, p = 0.
  * @param R         Upper triangular matrix (N*N, row-major). Output.
  * @param p         Converted gain vector (N). Output.
  * @param N         Filter order (number of taps).
  * @param delta_q16 Diagonal loading in Q15.16 (e.g., 655 = 0.01).
  */
void qr_rls_init(int32_t *R, int32_t *p, unsigned N, int32_t delta_q16);

/**
  * @brief QR-RLS update: incorporate new sample (d, x) into R and p.
  *        Uses pluggable vector_fn and rotate_fn for CORDIC operations.
  * @param R            Upper triangular matrix (N*N, row-major). In/out.
  * @param p            Converted gain vector (N). In/out.
  * @param x            Input vector [x(n), x(n-1), ..., x(n-N+1)] (N). In.
  * @param d            Desired output d(n). In.
  * @param N            Filter order.
  * @param lambda_q16   Forgetting factor in Q15.16 (e.g., 64225 = 0.98).
  * @param vector_fn_p  Vectoring function (hw_vector or sw_vector).
  * @param rotate_fn_p  Rotation function (hw_rotate or sw_rotate).
  */
void qr_rls_update(int32_t *R, int32_t *p, const int32_t *x, int32_t d,
                    unsigned N, int32_t lambda_q16,
                    vector_fn vector_fn_p, rotate_fn rotate_fn_p);
