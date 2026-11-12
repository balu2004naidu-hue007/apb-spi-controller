#ifndef SPI_X_H
#define SPI_X_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    volatile uint32_t CTRL;          /* 0x00 */
    volatile uint32_t STATUS;        /* 0x04 */
    volatile uint32_t CLK_DIV;       /* 0x08 */
    volatile uint32_t CONFIG;        /* 0x0C */
    volatile uint32_t TX_DATA;       /* 0x10 */
    volatile uint32_t RX_DATA;       /* 0x14 */
    volatile uint32_t INT_ENABLE;    /* 0x18 */
    volatile uint32_t INT_STATUS;    /* 0x1C */
    volatile uint32_t FIFO_CTRL;     /* 0x20 */
    volatile uint32_t CS_CTRL;       /* 0x24 */
    volatile uint32_t TRANSFER_LEN;  /* 0x28 */
    volatile uint32_t ERROR_STATUS;  /* 0x2C */
} spi_x_regs_t;

enum {
    SPI_X_CTRL_ENABLE = 1u << 0,
    SPI_X_CTRL_MASTER = 1u << 1,
    SPI_X_CONFIG_CPOL = 1u << 0,
    SPI_X_CONFIG_CPHA = 1u << 1,
    SPI_X_CONFIG_LSB_FIRST = 1u << 2,
    SPI_X_CONFIG_WIDTH_SHIFT = 3,
    SPI_X_CONFIG_WIDTH_8 = 0u << SPI_X_CONFIG_WIDTH_SHIFT,
    SPI_X_CONFIG_WIDTH_16 = 1u << SPI_X_CONFIG_WIDTH_SHIFT,
    SPI_X_CONFIG_WIDTH_32 = 2u << SPI_X_CONFIG_WIDTH_SHIFT,
    SPI_X_CONFIG_LOOPBACK = 1u << 5,
    SPI_X_STATUS_BUSY = 1u << 0,
    SPI_X_STATUS_TX_FULL = 1u << 1,
    SPI_X_STATUS_TX_EMPTY = 1u << 2,
    SPI_X_STATUS_RX_FULL = 1u << 3,
    SPI_X_STATUS_RX_EMPTY = 1u << 4,
    SPI_X_FIFO_RESET_TX = 1u << 0,
    SPI_X_FIFO_RESET_RX = 1u << 1,
    SPI_X_IRQ_DONE = 1u << 0,
    SPI_X_IRQ_RX_NOT_EMPTY = 1u << 1,
    SPI_X_IRQ_TX_SPACE = 1u << 2,
    SPI_X_IRQ_RX_OVERFLOW = 1u << 3,
    SPI_X_IRQ_TX_UNDERFLOW = 1u << 4,
    SPI_X_IRQ_TIMEOUT = 1u << 5,
    SPI_X_IRQ_PROTOCOL_ERROR = 1u << 6,
    SPI_X_IRQ_TX_OVERFLOW = 1u << 7,
    SPI_X_ERROR_TX_OVERFLOW = 1u << 0,
    SPI_X_ERROR_RX_OVERFLOW = 1u << 1,
    SPI_X_ERROR_TX_UNDERFLOW = 1u << 2,
    SPI_X_ERROR_TIMEOUT = 1u << 3,
    SPI_X_ERROR_PROTOCOL = 1u << 4
};

typedef struct {
    uint32_t divider;
    uint8_t mode;
    uint8_t bits;
    uint8_t lsb_first;
    uint8_t chip_select;
    uint8_t loopback;
    uint8_t master;
} spi_x_config_t;

static inline int spi_x_configure(spi_x_regs_t *regs, const spi_x_config_t *cfg)
{
    uint32_t width;
    uint32_t config;
    if (!regs || !cfg || cfg->mode > 3 || cfg->chip_select > 3)
        return -1;
    switch (cfg->bits) {
    case 8: width = SPI_X_CONFIG_WIDTH_8; break;
    case 16: width = SPI_X_CONFIG_WIDTH_16; break;
    case 32: width = SPI_X_CONFIG_WIDTH_32; break;
    default: return -1;
    }
    if (regs->STATUS & SPI_X_STATUS_BUSY)
        return -2;
    config = width | (cfg->lsb_first ? SPI_X_CONFIG_LSB_FIRST : 0u) |
        (cfg->loopback ? SPI_X_CONFIG_LOOPBACK : 0u) |
        ((cfg->mode & 2u) ? SPI_X_CONFIG_CPOL : 0u) |
        ((cfg->mode & 1u) ? SPI_X_CONFIG_CPHA : 0u);
    regs->CTRL = cfg->master ? SPI_X_CTRL_MASTER : 0u;
    regs->CONFIG = config;
    regs->CLK_DIV = cfg->divider & 0xffffu;
    regs->CS_CTRL = cfg->chip_select;
    regs->TRANSFER_LEN = 1u;
    return 0;
}

static inline int spi_x_write(spi_x_regs_t *regs, uint32_t word)
{
    if (!regs) return -1;
    if (regs->STATUS & SPI_X_STATUS_TX_FULL) return 1;
    regs->TX_DATA = word;
    return 0;
}

static inline int spi_x_read(spi_x_regs_t *regs, uint32_t *word)
{
    if (!regs || !word) return -1;
    if (regs->STATUS & SPI_X_STATUS_RX_EMPTY) return 1;
    *word = regs->RX_DATA;
    return 0;
}

static inline void spi_x_enable(spi_x_regs_t *regs, int enable)
{
    if (!regs) return;
    if (enable) regs->CTRL |= SPI_X_CTRL_ENABLE;
    else regs->CTRL &= ~SPI_X_CTRL_ENABLE;
}

static inline uint32_t spi_x_get_status(const spi_x_regs_t *regs)
{
    return regs ? regs->STATUS : 0u;
}

static inline uint32_t spi_x_irq_status(const spi_x_regs_t *regs)
{
    return regs ? regs->INT_STATUS : 0u;
}

static inline void spi_x_irq_clear(spi_x_regs_t *regs, uint32_t mask)
{
    if (regs) regs->INT_STATUS = mask & 0xffu;
}

static inline void spi_x_irq_enable(spi_x_regs_t *regs, uint32_t mask)
{
    if (regs) regs->INT_ENABLE = mask & 0xffu;
}

static inline void spi_x_reset_fifo(spi_x_regs_t *regs, uint32_t mask)
{
    if (regs) regs->FIFO_CTRL = mask & (SPI_X_FIFO_RESET_TX | SPI_X_FIFO_RESET_RX);
}

/* Software-bounded full-duplex master transfer; timeout does not abort an
 * already-started frame. A timed-out frame may complete in the background. */
static inline int spi_x_transfer(spi_x_regs_t *regs, uint32_t tx_word,
                                 uint32_t *rx_word, uint32_t timeout)
{
    if (!regs || !rx_word || timeout == 0u)
        return -1;
    if ((regs->CTRL & SPI_X_CTRL_MASTER) == 0u)
        return -2;
    if (regs->STATUS & SPI_X_STATUS_BUSY)
        return -3;
    if (regs->STATUS & SPI_X_STATUS_TX_FULL)
        return 1;
    if (!(regs->STATUS & SPI_X_STATUS_TX_EMPTY) || !(regs->STATUS & SPI_X_STATUS_RX_EMPTY))
        return -5;

    spi_x_irq_clear(regs, SPI_X_IRQ_DONE);
    regs->TX_DATA = tx_word;
    spi_x_enable(regs, 1);
    while (timeout-- != 0u) {
        if (spi_x_irq_status(regs) & SPI_X_IRQ_DONE) {
            spi_x_enable(regs, 0);
            spi_x_irq_clear(regs, SPI_X_IRQ_DONE);
            return spi_x_read(regs, rx_word);
        }
    }
    spi_x_enable(regs, 0);
    return -4;
}

#endif
