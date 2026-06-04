#include "uart.h"
#include "print.h"
#include "util.h"
#include "config.h"

#define ROM_MAX_SIZE 32
int main(void) {
    uart_init();
    char buffer[ROM_MAX_SIZE];

    uint32_t *rom = reg32(USER_ROM_BASE_ADDR, 0);
    int i         = 0;
    while (i < ROM_MAX_SIZE) {
        buffer[i] = (char)rom[i];
        if (buffer[i] == '\0') {
            break;
        }
        i++;
    }

    printf("ROM Test: %s\r\n", buffer);
    uart_write_flush();
    return 0;
}
