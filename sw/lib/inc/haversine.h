#ifndef CORDIC_H
#define CORDIC_H

#include <stdint.h>

// Using Q15.16 fixed-point format
#define CORDIC_FRACTIONAL_BITS 16
#define CORDIC_ONE             (1 << CORDIC_FRACTIONAL_BITS)
#define CORDIC_HALF_PI         (102943) // ~ 1.570796 * 2^16
#define CORDIC_PI              (205887) // ~ 3.141592 * 2^16
#define PI_Q16                 205887   /* pi * 65536 */
#define CORDIC_K               39797    // 0.607252935 * 2^16


#define ETH_LAT_RAD_Q16        54127
#define ETH_LON_RAD_Q16        9762
#define HB_LAT_RAD_Q16         54128
#define HB_LON_RAD_Q16         9760
#define MUL_FIXED(a, b)        ((int32_t)(((int64_t)(a) * (b)) / 65536))


typedef struct {
    int32_t lat;
    int32_t lon;
} gps_coord_t;


void cordic_sincos(int32_t angle, int32_t *sin_out, int32_t *cos_out);


void cordic_magphase(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out);


int32_t hs_dist(gps_coord_t a, gps_coord_t b);

int32_t cordic_sqrt(int32_t n);




// Helper macros for float conversion (useful for testing)
#define FLOAT_TO_Q16(x) ((int32_t)((x) * (1 << CORDIC_FRACTIONAL_BITS)))
#define Q16_TO_FLOAT(x) ((float)(x) / (1 << CORDIC_FRACTIONAL_BITS))



#endif // CORDIC_H
