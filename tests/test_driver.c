#include <assert.h>
#include <stdint.h>
#include <string.h>
#include "spi_x.h"

int main(void)
{
    spi_x_regs_t regs;
    spi_x_config_t cfg;
    uint32_t word = 0;
    memset(&regs, 0, sizeof(regs));
    memset(&cfg, 0, sizeof(cfg));
    cfg.master=1; cfg.mode=3; cfg.bits=16; cfg.divider=7;
    cfg.chip_select=2; cfg.lsb_first=1; cfg.loopback=1;
    assert(spi_x_configure(&regs,&cfg)==0);
    assert(regs.CTRL==SPI_X_CTRL_MASTER);
    assert(regs.CONFIG==(SPI_X_CONFIG_CPOL|SPI_X_CONFIG_CPHA|
                         SPI_X_CONFIG_LSB_FIRST|SPI_X_CONFIG_WIDTH_16|
                         SPI_X_CONFIG_LOOPBACK));
    assert(regs.CLK_DIV==7 && regs.CS_CTRL==2 && regs.TRANSFER_LEN==1);
    assert(spi_x_write(&regs,0x12345678u)==0 && regs.TX_DATA==0x12345678u);
    regs.STATUS=SPI_X_STATUS_TX_FULL;
    assert(spi_x_write(&regs,0)==1);
    regs.STATUS=SPI_X_STATUS_RX_EMPTY;
    assert(spi_x_read(&regs,&word)==1);
    regs.STATUS=0; regs.RX_DATA=0xA5;
    assert(spi_x_read(&regs,&word)==0 && word==0xA5);
    spi_x_enable(&regs,1); assert(regs.CTRL==(SPI_X_CTRL_MASTER|SPI_X_CTRL_ENABLE));
    spi_x_irq_enable(&regs,0x1ff); assert(regs.INT_ENABLE==0xff);
    spi_x_irq_clear(&regs,SPI_X_IRQ_DONE|SPI_X_IRQ_TX_OVERFLOW);
    assert(regs.INT_STATUS==(SPI_X_IRQ_DONE|SPI_X_IRQ_TX_OVERFLOW));
    spi_x_reset_fifo(&regs,3); assert(regs.FIFO_CTRL==3);
    assert(spi_x_get_status(&regs)==regs.STATUS);
    assert(spi_x_transfer(NULL,0,&word,10)==-1);
    assert(spi_x_transfer(&regs,0,NULL,10)==-1);
    assert(spi_x_transfer(&regs,0,&word,0)==-1);
    regs.CTRL=0; assert(spi_x_transfer(&regs,0,&word,10)==-2);
    regs.CTRL=SPI_X_CTRL_MASTER; regs.STATUS=SPI_X_STATUS_BUSY;
    assert(spi_x_transfer(&regs,0,&word,10)==-3);
    regs.STATUS=SPI_X_STATUS_TX_FULL;
    assert(spi_x_transfer(&regs,0,&word,10)==1);
    regs.STATUS=SPI_X_STATUS_RX_EMPTY;
    assert(spi_x_transfer(&regs,0,&word,10)==-5);
    cfg.bits=24; assert(spi_x_configure(&regs,&cfg)==-1);
    cfg.bits=8; cfg.mode=4; assert(spi_x_configure(&regs,&cfg)==-1);
    return 0;
}
