#include "spi_x.h"

#ifndef SPI_X_BASE
#define SPI_X_BASE 0x40010000u
#endif

static spi_x_regs_t *const spi = (spi_x_regs_t *)(uintptr_t)SPI_X_BASE;

int main(void)
{
    const spi_x_config_t config = {
        .divider=4u, .mode=0u, .bits=8u, .lsb_first=0u,
        .chip_select=0u, .loopback=1u, .master=1u
    };
    uint32_t received;
    if (spi_x_configure(spi,&config)!=0) return 1;
    spi_x_enable(spi,1);
    if (spi_x_transfer(spi,0xA5u,&received,1000000u)!=0) return 2;
    return (received&0xffu)==0xA5u ? 0 : 3;
}
