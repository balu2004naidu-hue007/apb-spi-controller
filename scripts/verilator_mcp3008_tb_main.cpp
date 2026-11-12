#include "Vtb_icebreaker_mcp3008.h"
#include "verilated.h"

int main(int argc, char** argv) {
    VerilatedContext context;
    context.commandArgs(argc, argv);
    context.traceEverOn(true);
    Vtb_icebreaker_mcp3008 top{&context};
    while (!context.gotFinish()) {
        top.eval();
        if (!context.gotFinish()) context.timeInc(1);
    }
    top.final();
    return 0;
}
