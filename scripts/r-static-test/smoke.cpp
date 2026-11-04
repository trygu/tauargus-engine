#include "TauArgus.h"
#include "HiTaSCtrl.h"
#include "RounderCtrl.h"
#include <iostream>
#include <highs/interfaces/highs_c_api.h>
extern "C" int S_CRPopenSOLVER(void);
extern "C" int S_CRPcloseSOLVER(void);
extern void *CRPenvS;

int main() {
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
