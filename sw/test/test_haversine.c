#include "haversine.h"
#include "uart.h"
#include "print.h"
#include "util.h"
#include "config.h"

#define ABS(x) ((x) < 0 ? -(x) : (x))

int main(void) {
    uart_init();
    uint32_t t0, t1;
    printf("Starting Haversine Tests...\n");
    // gps_coord_t p1  = {.lat = 54228, .lon = 9744};
    // gps_coord_t p2  = {.lat = 54229, .lon = 9742};

    // gps_coord_t p1  = {.lat = 54228, .lon = 9744};
    // gps_coord_t p2  = {.lat = 55874, .lon = 2688};

    gps_coord_t p1  = {.lat = 54228, .lon = 9744};
    gps_coord_t p2  = {.lat = 55096, .lon = 13217};
    t0              = get_mcycle();
    int32_t dist    = hs_dist(p1, p2);
    t1              = get_mcycle();
    uint32_t cycles = t1 - t0;

    printf("Test Input: ETH to HB\n");
    // printf("Expected: ~130m\n");
    // printf("Expected: ~490km\n");
    printf("Expected: ~240km\n");
    printf("Calculated: %d m\n", dist);
    printf("Cycles for Op: %d\n\n", cycles);
    if (dist > 120 && dist < 140) {
        printf("RESULT: PASS\n");
    } else {
        printf("RESULT: FAIL (Verify your CORDIC scaling factors)\n");
    }


    uart_write_flush();
    return 0;
}
