#pragma once
#include <stdint.h>
#include "util.h"

// Angle format: normalized where 2pi = 2^32
#define CORDIC_FRACTIONAL_BITS 16
#define CORDIC_ONE             (1 << CORDIC_FRACTIONAL_BITS)
#define CORDIC_HALF_PI         ((uint32_t)0x40000000) // pi/2  ->  2^30
#define CORDIC_PI              ((uint32_t)0x80000000) // pi    ->  2^31

#define CORDIC_K               39797 // 1/K ~ 0.607252935 * 2^16
#define CORDIC_ITERATIONS      16
static const uint32_t atan_table[CORDIC_ITERATIONS] = {
    536870912, // atan(2^0) = pi/4  ->  2^32 / 8
    316933406, // atan(2^-1)
    167466358, // atan(2^-2)
    85012769,  // atan(2^-3)
    42673528,  // atan(2^-4)
    21354918,  // atan(2^-5)
    10680707,  // atan(2^-6)
    5340354,   // atan(2^-7)
    2670177,   // atan(2^-8)
    1335088,   // atan(2^-9)
    667544,    // atan(2^-10)
    333772,    // atan(2^-11)
    166886,    // atan(2^-12)
    83443,     // atan(2^-13)
    41722,     // atan(2^-14)
    20861      // atan(2^-15)
};

#define CORDIC_BASE_ADDR     0x30000000
#define OUTPUT_X_OFFSET      0x00
#define OUTPUT_Y_OFFSET      0x04
#define OUTPUT_ANGLE_OFFSET  0x08
#define STATUS_OFFSET        0x0C
#define INPUT_ANGLE_OFFSET   0x10
#define PRECISION_SFR_OFFSET 0x14
#define MISC_SFR_OFFSET      0x18
#define OPTYPE_SFR_OFFSET    0x1C
#define OPMODE_SFR_OFFSET    0x20
#define INPUT_X_OFFSET       0x24
#define INPUT_Y_OFFSET       0x28
#define DRCG_SFR_OFFSET      0x2C

#define IRQ_CORDIC           20

// CORDIC precision: precision value = num_iterations - 1
// 0x0 = 1 iteration, 0xF = 16 iterations (default)
#define CORDIC_PREC_1        0x0
#define CORDIC_PREC_FULL     0xF
/**
  * @brief Set CORDIC iteration precision.
  * @param prec Number of iterations minus one (0x0 = 1 iter, 0xF = 16 iter).
  */
static inline void cordic_set_precision(uint32_t prec) {
    *reg32(CORDIC_BASE_ADDR, PRECISION_SFR_OFFSET) = prec;
}
/**
  * @brief Enable or disable dynamic read clock gating (DRCG) for the CORDIC module.
  * @param enable 1 to enable DRCG, 0 to disable.
  */
static inline void cordic_set_drcg(uint32_t enable) {
    *reg32(CORDIC_BASE_ADDR, DRCG_SFR_OFFSET) = enable;
}
/**
  * @brief Compare two arrays with relative + absolute tolerance.
  *        rel_pct=0: abs_tol only.  rel_pct=1: ~0.78%.  rel_pct=3: ~3.125%.
  * @return 1 if all elements match within tolerance, 0 otherwise.
  */
static inline int cmp_rel(const int32_t x[], const int32_t y[], unsigned N, int32_t rel_pct, int32_t abs_tol) {
    unsigned shift = rel_pct == 0 ? 31 : rel_pct == 1 ? 7 : 5;
    for (unsigned i = 0; i < N; i++) {
        int32_t d = x[i] - y[i];
        if (d < 0) d = -d;
        int32_t ref = y[i];
        if (ref < 0) ref = -ref;
        int32_t t = abs_tol + (int32_t)((uint32_t)ref >> shift);
        if (d > t) return 0;
    }
    return 1;
}
/**
  * @brief Rotates an arbitrary vector (x, y) by an angle using HW CORDIC (opmode=1)
  *        Output includes CORDIC K_gain (~1.647). SW must post-multiply by CORDIC_K (39797)
  *        to compensate: result = (output * CORDIC_K) >> 16.
  * @param x X component (Q15.16)
  * @param y Y component (Q15.16)
  * @param angle Angle in normalized format (2pi = 2^32)
  * @param x_out Pointer to rotated X output (K_gain-scaled, Q15.16)
  * @param y_out Pointer to rotated Y output (K_gain-scaled, Q15.16)
  */
static inline void hw_rotate(int32_t x, int32_t y, uint32_t angle, int32_t *x_out, int32_t *y_out) {
    *reg32(CORDIC_BASE_ADDR, OPMODE_SFR_OFFSET) = 1;
    *reg32(CORDIC_BASE_ADDR, INPUT_X_OFFSET)    = x;
    *reg32(CORDIC_BASE_ADDR, INPUT_Y_OFFSET)    = y;
    *reg32(CORDIC_BASE_ADDR, INPUT_ANGLE_OFFSET)      = angle;
    while (*reg32(CORDIC_BASE_ADDR, STATUS_OFFSET) == 1) {
    }
    *x_out = *reg32(CORDIC_BASE_ADDR, OUTPUT_X_OFFSET);
    *y_out = *reg32(CORDIC_BASE_ADDR, OUTPUT_Y_OFFSET);
}
/**
  * @brief SW CORDIC rotation: rotates (x, y) by angle using the same
  *        quadrant-based pre-rotation as the RTL. Output includes K-gain;
  *        caller applies kc() to compensate.
  * @param x      X component (Q15.16).
  * @param y      Y component (Q15.16).
  * @param angle  Angle in normalized format (2pi = 2^32).
  * @param x_out  Pointer to rotated X output (Q15.16).
  * @param y_out  Pointer to rotated Y output (Q15.16).
  */
static inline void sw_rotate(int32_t x, int32_t y, uint32_t angle, int32_t *x_out, int32_t *y_out) {
    // Quadrant-based pre-rotation (matches RTL cordic_engine):
    // Top 2 bits pre-rotate (x,y) by quadrant*90deg, residual z in [0, pi/2).
    uint32_t quadrant = angle >> 30;
    int32_t z         = (int32_t)(angle & 0x3FFFFFFF);
    int32_t xi, yi;

    switch (quadrant) {
    case 0:
        xi = x;
        yi = y;
        break;
    case 1:
        xi = -y;
        yi = x;
        break;
    case 2:
        xi = -x;
        yi = -y;
        break;
    default:
        xi = y;
        yi = -x;
        break;
    }

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = xi;
        if (z < 0) {
            xi = x_temp + (yi >> i);
            yi = yi - (x_temp >> i);
            z += atan_table[i];
        } else {
            xi = x_temp - (yi >> i);
            yi = yi + (x_temp >> i);
            z -= atan_table[i];
        }
    }
    *x_out = xi;
    *y_out = yi;
}
/**
  * @brief Polls the hardware CORDIC for sine and cosine values
  * @param angle Angle in normalized format (2pi = 2^32).
  * @param sin_out Pointer to store the computed sine value (Q15.16 format).
  * @param cos_out Pointer to store the computed cosine value (Q15.16 format).
  */
static inline void hw_sincos(uint32_t angle, int32_t *sin_out, int32_t *cos_out) {
    *reg32(CORDIC_BASE_ADDR, OPMODE_SFR_OFFSET) = 0;
    *reg32(CORDIC_BASE_ADDR, INPUT_ANGLE_OFFSET)      = angle;
    while (*reg32(CORDIC_BASE_ADDR, STATUS_OFFSET) == 1) {
    }
    *cos_out = *reg32(CORDIC_BASE_ADDR, OUTPUT_X_OFFSET);
    *sin_out = *reg32(CORDIC_BASE_ADDR, OUTPUT_Y_OFFSET);
}
/**
  * @brief HW CORDIC vectoring mode: compute magnitude and phase of vector (x, y).
  *        Input (x, y) is rotated to X-axis; X output = magnitude, Z output = angle.
  *        Right half-plane only (x >= 0). Output includes K_gain; apply kc() to compensate.
  * @param x         X component (Q15.16), must be >= 0.
  * @param y         Y component (Q15.16).
  * @param mag_out   Pointer to store magnitude (K_gain-scaled, Q15.16).
  * @param phase_out Pointer to store phase angle (normalized format, 2pi = 2^32).
  */
static inline void hw_vector(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out) {
    *reg32(CORDIC_BASE_ADDR, OPMODE_SFR_OFFSET) = 2;
    *reg32(CORDIC_BASE_ADDR, INPUT_X_OFFSET)    = x;
    *reg32(CORDIC_BASE_ADDR, INPUT_Y_OFFSET)    = y;  // Triggers start in vectoring mode
    while (*reg32(CORDIC_BASE_ADDR, STATUS_OFFSET) == 1) {
    }
    *mag_out   = *reg32(CORDIC_BASE_ADDR, OUTPUT_X_OFFSET);
    *phase_out = *reg32(CORDIC_BASE_ADDR, OUTPUT_ANGLE_OFFSET);
}
/**
  * @brief SW CORDIC: compute sine and cosine of an angle (Rotation Mode).
  *        Quadrant-based pre-rotation matches RTL cordic_engine.
  * @param angle  Angle in normalized format (2pi = 2^32).
  * @param sin_out Pointer to store the sine (Q15.16).
  * @param cos_out Pointer to store the cosine (Q15.16).
  */
static inline void sw_sincos(uint32_t angle, int32_t *sin_out, int32_t *cos_out) {
    uint32_t quadrant = angle >> 30;
    int32_t z         = (int32_t)(angle & 0x3FFFFFFF);
    int32_t x, y;

    switch (quadrant) {
    case 0:
        x = CORDIC_K;
        y = 0;
        break;
    case 1:
        x = 0;
        y = CORDIC_K;
        break;
    case 2:
        x = -CORDIC_K;
        y = 0;
        break;
    default:
        x = 0;
        y = -CORDIC_K;
        break;
    }

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        if (z < 0) {
            x = x_temp + (y >> i);
            y = y - (x_temp >> i);
            z += atan_table[i];
        } else {
            x = x_temp - (y >> i);
            y = y + (x_temp >> i);
            z -= atan_table[i];
        }
    }

    *cos_out = x;
    *sin_out = y;
}
/**
  * @brief SW CORDIC: compute magnitude and phase of a vector (Vectoring Mode).
  *        Magnitude is K-gain compensated. Phase in normalized format (2pi = 2^32).
  * @param x         X-coordinate (Q15.16).
  * @param y         Y-coordinate (Q15.16).
  * @param mag_out   Pointer to store magnitude (Q15.16).
  * @param phase_out Pointer to store phase (normalized).
  */
static inline void sw_magphase(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out) {
    int32_t z = 0;

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        int32_t y_temp = y;

        if (y < 0) {
            x = x_temp - (y_temp >> i);
            y = y_temp + (x_temp >> i);
            z -= atan_table[i];
        } else {
            x = x_temp + (y_temp >> i);
            y = y_temp - (x_temp >> i);
            z += atan_table[i];
        }
    }

    *mag_out   = (int32_t)(((int64_t)x * CORDIC_K) >> CORDIC_FRACTIONAL_BITS);
    *phase_out = z;
}

/**
  * @brief SW CORDIC vectoring: compute magnitude and phase of (x, y).
  *        Output magnitude is K-scaled (caller must apply kc() to compensate).
  *        Matches hw_vector() interface for pluggable function pointers.
  * @param x         X-coordinate (Q15.16).
  * @param y         Y-coordinate (Q15.16).
  * @param mag_out   Pointer to store K-scaled magnitude (Q15.16).
  * @param phase_out Pointer to store phase (normalized, 2pi = 2^32).
  */
static inline void sw_vector(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out) {
    int32_t z = 0;

    // Full circle: pre-rotate by 180° when X < 0
    if (x < 0) {
        x = -x;
        y = -y;
        z = (int32_t)0x80000000;  // pi in normalized angle
    }

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        int32_t y_temp = y;

        if (y < 0) {
            x = x_temp - (y_temp >> i);
            y = y_temp + (x_temp >> i);
            z -= atan_table[i];
        } else {
            x = x_temp + (y_temp >> i);
            y = y_temp - (x_temp >> i);
            z += atan_table[i];
        }
    }

    *mag_out   = x;  // K-scaled, caller applies kc()
    *phase_out = z;
}

// Helper macros for float-to-angle conversion (useful for testing)
#define FLOAT_TO_Q16(x) ((int32_t)(uint32_t)((x) * (1LL << 32) / 6.283185307179586))
#define Q16_TO_FLOAT(x) ((float)((int64_t)(x) * 6.283185307179586 / (1LL << 32)))
