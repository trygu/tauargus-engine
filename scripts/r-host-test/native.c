#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void native_output(void) {
    printf("C output %d\n", 7);
    fprintf(stderr, "C error\n");
}
void native_exit(void) { exit(7); }
void native_abort(void) { abort(); }
int native_file(void) {
    FILE *file = tmpfile();
    char buffer[64] = {0};
    if (!file) return 1;
    /* The literal and comment exit(9) must survive source adaptation. */
    fprintf(file, "%s", "literal exit(9)");
    fflush(file);
    rewind(file);
    size_t count = fread(buffer, 1, sizeof(buffer) - 1, file);
    fclose(file);
    return count != 15 || strcmp(buffer, "literal exit(9)") != 0;
}
