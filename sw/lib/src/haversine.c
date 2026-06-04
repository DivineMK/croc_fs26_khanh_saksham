#include "haversine.h"

// Number of CORDIC iterations
#define CORDIC_ITERATIONS 16

// Pre-computed arctangents: atan(2^-i) in Q15.16 format
// Computed as: round(atan(2^-i) * 2^16)
static const int32_t atan_table[CORDIC_ITERATIONS] = {
    51472, // atan(2^0) = 0.785398
    30386, // atan(2^-1) = 0.463647
    16055, // atan(2^-2) = 0.244978
    8150,  // atan(2^-3) = 0.124354
    4091,  // atan(2^-4) = 0.062418
    2047,  // atan(2^-5) = 0.031239
    1024,  // atan(2^-6) = 0.015623
    512,   // atan(2^-7) = 0.007812
    256,   // atan(2^-8) = 0.003906
    128,   // atan(2^-9) = 0.001953
    64,    // atan(2^-10) = 0.000976
    32,    // atan(2^-11) = 0.000488
    16,    // atan(2^-12) = 0.000244
    8,     // atan(2^-13) = 0.000122
    4,     // atan(2^-14) = 0.000061
    2      // atan(2^-15) = 0.000030
};

void cordic_sincos(int32_t angle, int32_t *sin_out, int32_t *cos_out) {
    int32_t x = CORDIC_K;
    int32_t y = 0;
    int32_t z = angle;

    for (int i = 0; i < CORDIC_ITERATIONS; ++i) {
        int32_t x_temp = x;
        int32_t y_temp = y;

        if (z < 0) {
            x = x_temp + (y_temp >> i);
            y = y_temp - (x_temp >> i);
            z += atan_table[i];
        } else {
            x = x_temp - (y_temp >> i);
            y = y_temp + (x_temp >> i);
            z -= atan_table[i];
        }
    }

    *cos_out = x;
    *sin_out = y;
}


void cordic_magphase(int32_t x, int32_t y, int32_t *mag_out, int32_t *phase_out) {
    int32_t z = 0;

    // 1. Force the vector into the right half-plane (x > 0)
    // This is required for vectoring mode to converge.
    if (x < 0) {
        x = -x;
        y = -y;
        z = (y >= 0) ? CORDIC_PI : -CORDIC_PI;
    }

    for (int i = 0; i < CORDIC_ITERATIONS; i++) {
        int32_t x_temp = x;
        // Use a conditional assignment to avoid branching inside the loop
        if (y > 0) {
            x = x_temp + (y >> i);
            y = y - (x_temp >> i);
            z += atan_table[i];
        } else {
            x = x_temp - (y >> i);
            y = y + (x_temp >> i);
            z -= atan_table[i];
        }
    }

    *mag_out   = (int32_t)(((int64_t)x * 107918) >> 16);
    *phase_out = z;
}

int32_t cordic_sqrt(int32_t n) {
    // if (n <= 0) return 0;
    // int32_t x = n + 16384;
    // int32_t y = n - 16384;
    // for (int i = 1; i <= 16; ++i) {
    //     int32_t x_t = x;
    //     if (y < 0) {
    //         x += (y >> i);
    //         y += (x_t >> i);
    //     } else {
    //         x -= (y >> i);
    //         y -= (x_t >> i);
    //     }
    // }
    // return (int32_t)(((int64_t)x * 79134) >> 16); // Scale by 1/Kh
    if (n <= 0) return 0;

    // 1. Normalize: Scale n up until it is in range [0.25, 1.0]
    // 0.25 in Q16 is 16384.
    int32_t shift = 0;
    while (n < 16384 && shift < 30) {
        n <<= 2; // Shift by 2 bits = multiply by 4
        shift++;
    }

    // 2. Perform Hyperbolic CORDIC
    int32_t x = n + 16384;
    int32_t y = n - 16384;
    for (int i = 1; i <= 16; ++i) {
        int32_t x_t = x;
        if (y < 0) {
            x += (y >> i);
            y += (x_t >> i);
        } else {
            x -= (y >> i);
            y -= (x_t >> i);
        }
    }

    // Result is scaled by Kh (0.828159)
    int32_t res = (int32_t)(((int64_t)x * 79134) >> 16);

    // 3. Denormalize: Shift result back
    // We shifted n by 2*shift bits, so we shift result by shift bits
    return res >> shift;
}


int32_t hs_dist(gps_coord_t a, gps_coord_t b) {
    int32_t dlat = b.lat - a.lat;
    int32_t dlon = b.lon - a.lon;

    int32_t sin_dlat2, cos_dlat2, sin_a, cos_a, sin_b, cos_b, sin_dlon2, cos_dlon2;
    cordic_sincos(dlat >> 1, &sin_dlat2, &cos_dlat2);
    cordic_sincos(a.lat, &sin_a, &cos_a);
    cordic_sincos(b.lat, &sin_b, &cos_b);
    cordic_sincos(dlon >> 1, &sin_dlon2, &cos_dlon2);

    /*Extra logic*/
    int64_t s_dlat2  = MUL_FIXED(sin_dlat2, sin_dlat2);
    int64_t cos_p    = MUL_FIXED(cos_a, cos_b);
    int64_t s_dlon2  = MUL_FIXED(sin_dlon2, sin_dlon2);
    int64_t h        = s_dlat2 + MUL_FIXED(cos_p, s_dlon2);



    // h = sin²(dlat/2) + cos(lat1)*cos(lat2)*sin²(dlon/2)
    /*Extra logic*/
    // int32_t h = MUL_FIXED(sin_dlat2, sin_dlat2) + MUL_FIXED(MUL_FIXED(cos_a, cos_b), MUL_FIXED(sin_dlon2, sin_dlon2));

    // c = 2 * atan2(sqrt(h), sqrt(1-h))
    int32_t sqrt_h   = cordic_sqrt((int32_t)h);
    int32_t sqrt_1_h = cordic_sqrt(65536 - (int32_t)h);

    int32_t mag_unused, atan_fixed;
    cordic_magphase(sqrt_1_h, sqrt_h, &mag_unused, &atan_fixed);

    // d = R * c
    return (int32_t)(((int64_t)6371000 * (atan_fixed << 1)) / 65536);
}
