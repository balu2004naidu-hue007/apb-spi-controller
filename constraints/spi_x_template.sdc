# Portable SDC TEMPLATE, not device sign-off. Fill every value below from the
# selected FPGA/ASIC clock plan, external SPI device timing, and board delays.
# Run one static CPOL/CPHA scenario at a time; the sample clock polarity mux is
# mode-controlled and the modes are not concurrent clock waveforms.

set PCLK_PERIOD_NS 10.000
set SCLK_EXT_PERIOD_NS 100.000
set SPI_MOSI_IN_MAX_NS 5.000
set SPI_MOSI_IN_MIN_NS 0.000
set SPI_CS_IN_MAX_NS 5.000
set SPI_CS_IN_MIN_NS 0.000
set SPI_MISO_OUT_MAX_NS 5.000
set SPI_MISO_OUT_MIN_NS 0.000
set SPI_MASTER_OUT_MAX_NS 5.000
set SPI_MASTER_OUT_MIN_NS 0.000
set GRAY_CDC_MAX_NS $PCLK_PERIOD_NS

create_clock -name PCLK -period $PCLK_PERIOD_NS [get_ports pclk]
create_clock -name SCLK_EXT -period $SCLK_EXT_PERIOD_NS [get_ports spi_sclk_in]

# The master toggles SCLK at most once per PCLK when BAUD=0/1. This fastest
# legal clock is conservative for all programmable divider values.
create_generated_clock -name MASTER_SCLK -source [get_ports pclk] -divide_by 2 [get_ports spi_sclk_out]

# Select exactly one generated sample clock definition per CPOL/CPHA scenario:
# CPOL==CPHA (modes 0/3):
create_generated_clock -name SLAVE_SAMPLE -source [get_ports spi_sclk_in] -divide_by 1 [get_nets slave_sample_clk]
# CPOL!=CPHA (modes 1/2), use this command instead of the line above:
# create_generated_clock -name SLAVE_SAMPLE -source [get_ports spi_sclk_in] -divide_by 1 -invert [get_nets slave_sample_clk]

# Do not blanket false-path the PCLK/SCLK domains: that would hide the Gray
# pointer bus-skew requirement. These targeted max-delay constraints preserve
# a bound on each Gray bus to the first synchronizer stage.
set_max_delay -datapath_only $PCLK_PERIOD_NS -from [get_registers -hierarchical *u_tx_slave*wr_gray_reg*] -to [get_registers -hierarchical *u_tx_slave*wr_gray_rq1_reg*]
set_max_delay -datapath_only $SCLK_EXT_PERIOD_NS -from [get_registers -hierarchical *u_tx_slave*rd_gray_reg*] -to [get_registers -hierarchical *u_tx_slave*rd_gray_wq1_reg*]
set_max_delay -datapath_only $SCLK_EXT_PERIOD_NS -from [get_registers -hierarchical *u_rx_slave*wr_gray_reg*] -to [get_registers -hierarchical *u_rx_slave*wr_gray_rq1_reg*]
set_max_delay -datapath_only $PCLK_PERIOD_NS -from [get_registers -hierarchical *u_rx_slave*rd_gray_reg*] -to [get_registers -hierarchical *u_rx_slave*rd_gray_wq1_reg*]

# Sticky completion handshake into PCLK; cut only the asynchronous first-stage
# endpoint. Stage two and all following logic stay timed in PCLK.
set_false_path -from [get_registers -hierarchical *slave_event_pending*] -to [get_registers -hierarchical *slave_evt_q1*]

set_input_delay -clock SCLK_EXT -max $SPI_MOSI_IN_MAX_NS [get_ports spi_mosi_in]
set_input_delay -clock SCLK_EXT -min $SPI_MOSI_IN_MIN_NS [get_ports spi_mosi_in]
set_input_delay -clock SCLK_EXT -max $SPI_CS_IN_MAX_NS [get_ports spi_cs_in_n]
set_input_delay -clock SCLK_EXT -min $SPI_CS_IN_MIN_NS [get_ports spi_cs_in_n]
set_output_delay -clock SCLK_EXT -max $SPI_MISO_OUT_MAX_NS [get_ports spi_miso_out]
set_output_delay -clock SCLK_EXT -min $SPI_MISO_OUT_MIN_NS [get_ports spi_miso_out]
set_output_delay -clock MASTER_SCLK -max $SPI_MASTER_OUT_MAX_NS [get_ports {spi_mosi_out spi_cs_out_n}]
set_output_delay -clock MASTER_SCLK -min $SPI_MASTER_OUT_MIN_NS [get_ports {spi_mosi_out spi_cs_out_n}]

# Review before use: adapt get_registers/get_nets syntax to the selected tool,
# confirm every query resolves to the intended endpoints, set input/output
# delays and uncertainty from datasheets/board routing, and run CDC + STA.
