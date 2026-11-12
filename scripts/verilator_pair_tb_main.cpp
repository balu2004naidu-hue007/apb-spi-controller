#include "Vtb_spi_x_pair.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    Vtb_spi_x_pair top{&context};
    while (!context.gotFinish()) {
        top.eval();
        if (!context.gotFinish()) context.timeInc(1);
    }
    top.final();
    return 0;
}
