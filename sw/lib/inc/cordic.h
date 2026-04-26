#ifndef CORDIC_H
#define CORDIC_H

#include <stdint.h>

// Using Q15.16 fixed-point format
#define CORDIC_FRACTIONAL_BITS 16
#define CORDIC_ONE (1 << CORDIC_FRACTIONAL_BITS)
#define CORDIC_HALF_PI (102943) // ~ 1.570796 * 2^16
#define CORDIC_PI (205887)      // ~ 3.141592 * 2^16

#define CORDIC_K 39797          // 0.607252935 * 2^16

/**
 * @brief Computes sine and cosine of an angle using CORDIC (Rotation Mode)
 * 
 * @param angle Angle in radians (Q15.16 fixed-point format). Must be in range [-pi/2, pi/2].
 * @param sin_out Pointer to store the computed sine value (Q15.16 format).
 * @param cos_out Pointer to store the computed cosine value (Q15.16 format).
 */
void cordic_sincos(int32_t angle, int32_t *sin_out, int32_t *cos_out);

/**
 * @brief Computes magnitude and phase of a vector using CORDIC (Vectoring Mode)
 * 
 * @param x X-coordinate of the vector (Q15.16 fixed-point format). Must be > 0.
 * @param y Y-coordinate of the vector (Q15.16 fixed-point format).
 * @param mag_out Pointer to store the computed magnitude (Q15.16 format).
 * @param phase_out Pointer to store the computed phase in radians (Q15.16 format).
 */
void cordic_magphase(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out);

// Helper macros for float conversion (useful for testing)
#define FLOAT_TO_Q16(x) ((int32_t)((x) * (1 << CORDIC_FRACTIONAL_BITS)))
#define Q16_TO_FLOAT(x) ((float)(x) / (1 << CORDIC_FRACTIONAL_BITS))

#endif // CORDIC_H
