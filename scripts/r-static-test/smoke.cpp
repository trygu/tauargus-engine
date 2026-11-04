#include "TauArgus.h"
#include "HiTaSCtrl.h"
#include "RounderCtrl.h"
#include "AMyIO.h"
#include <iostream>
#include <stdexcept>
#include <highs/interfaces/highs_c_api.h>
extern "C" int S_CRPopenSOLVER(void);
extern "C" int S_CRPcloseSOLVER(void);
extern void *CRPenvS;

int main() {
    FILE *input = tmpfile();
    if (!input) return 4;
    fputs("12 3.5\n", input);
    rewind(input);
    int integer = 0;
    double real = 0;
    ScanFile(input, 2, "%d %lf", &integer, &real);
    if (integer != 12 || real != 3.5) return 5;
    ScanFile(input, 0, "\n");
    try {
        ScanFile(input, 1, "%d", &integer);
        fclose(input);
        return 6;
    } catch (const std::runtime_error &) {
        // ScanFile closes a rejected input file before reporting the error.
    }
    TauArgus core;
    HiTaSCtrl hitas;
    RounderCtrl rounder;
    if (core.GetVersion().empty() || hitas.GetVersion().empty() ||
        rounder.GetVersion().empty()) return 1;
#ifdef TAUARGUS_MAX_THREADS
    if (S_CRPopenSOLVER() != 0) return 2;
    HighsInt threads = 0;
    const bool bounded = Highs_getIntOptionValue(CRPenvS, "threads", &threads) == kHighsStatusOk &&
                         threads == TAUARGUS_MAX_THREADS;
    S_CRPcloseSOLVER();
    if (!bounded) return 3;
#endif
    std::cout << "All three controllers link into one executable\n";
    return 0;
}
