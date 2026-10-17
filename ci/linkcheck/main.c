/* Bundle link + load check.
 *
 * The program links the bundled tauargus_csp library by path (see
 * CMakeLists.txt) and resolves its exported extern "C" audit entry
 * point. Building it proves the bundle's lib directory provides the
 * symbol; running it proves the shared object (or DLL) loads from the
 * unpacked bundle location. It takes the function's address and
 * returns 0 without calling it, so the check is independent of the
 * solver state of the host machine.
 */
extern int TauAuditJj(const char *jjfile,
                      int *n_out,
                      long **cell_idx,
                      double **a_min,
                      double **a_max,
                      double **a_value,
                      char **a_status,
                      int **a_unsafe);

int main(void) {
    int (*fn)(const char *, int *, long **, double **,
              double **, double **, char **, int **) = TauAuditJj;
    (void)fn;
    return 0;
}
