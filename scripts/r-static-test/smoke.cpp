#include "TauArgus.h"
#include "HiTaSCtrl.h"
#include "RounderCtrl.h"
#include <iostream>

int main() {
    TauArgus core;
    HiTaSCtrl hitas;
    RounderCtrl rounder;
    if (core.GetVersion().empty() || hitas.GetVersion().empty() ||
        rounder.GetVersion().empty()) return 1;
    std::cout << "All three controllers link into one executable\n";
    return 0;
}
