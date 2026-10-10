// Output helpers the MIND kernel calls for print(). Linked by
// scripts/run-checks.sh in place of the MIND CPU runtime.
#include <stdint.h>
#include <stdio.h>

int64_t printI64(int64_t value) {
    printf("%lld", (long long)value);
    return 0;
}

int64_t printNewline(void) {
    putchar('\n');
    return 0;
}
