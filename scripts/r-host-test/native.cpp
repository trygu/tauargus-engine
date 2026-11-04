#include <iostream>
using std::cout;
void native_cpp_output() { cout << "C++ output\n"; std::cerr << "C++ error\n"; }

const char *native_raw_literal() { return R"tag(stdout std::cout exit(9))tag"; }
