#include "Vtb_spi_x.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    context.traceEverOn(true);
    Vtb_spi_x top{&context};
    while (!context.gotFinish()) {
        top.eval();
        if (!context.gotFinish()) context.timeInc(1);
    }
    top.final();
    return 0;
}
