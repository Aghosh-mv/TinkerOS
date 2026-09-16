/* Korlang v0.2 — Generated C code */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>
#include <stdarg.h>

/* Korlang runtime */
typedef struct { const char* data; size_t len; } kl_string;
static inline kl_string kl_str(const char* s) { return (kl_string){s, strlen(s)}; }
static inline kl_string kl_strn(const char* s, size_t n) { return (kl_string){s, n}; }
#define kl_print(s) printf("%.*s\n", (int)(s).len, (s).data)
#define kl_fmt(buf, ...) sprintf(buf, __VA_ARGS__)
static inline kl_string kl_interp(const char* fmt, ...) {
    char buf[512]; va_list args; va_start(args, fmt);
    vsnprintf(buf, 512, fmt, args); va_end(args);
    return kl_str(buf);
}

int32_t add(int32_t a, int32_t b);
typedef struct User {
    kl_string name;
    int32_t age;
} User;

int main(void) {
        kl_string name = kl_str("KorrinOS");
        double version = 1.3;
        printf("%.*s\n", (int)kl_interp("Hello from %s v%g!", name.data, version).len, kl_interp("Hello from %s v%g!", name.data, version).data);
        printf("%.*s\n", (int)kl_str("Korlang is working!").len, kl_str("Korlang is working!").data);
        int32_t x = 42;
        double y = 3.14;
        _Bool flag = 1;
        kl_string msg = kl_str("testing");
        if ((x > 40)) {
                printf("%.*s\n", (int)kl_str("x is greater than 40").len, kl_str("x is greater than 40").data);
        } else {
                printf("%.*s\n", (int)kl_str("x is 40 or less").len, kl_str("x is 40 or less").data);
        }
        for (int64_t i = 0; i < 5; i++) {
                printf("%.*s\n", (int)kl_interp("count: %ld", i).len, kl_interp("count: %ld", i).data);
        }
        int32_t counter = 0;
        while ((counter < 3)) {
                printf("%.*s\n", (int)kl_interp("counter = %ld", counter).len, kl_interp("counter = %ld", counter).data);
                counter = (counter + 1);
        }
        User user = (User){kl_str("Alice"), 30};
        printf("%.*s\n", (int)kl_interp("User: %ld, Age: %ld", user.name, user.age).len, kl_interp("User: %ld, Age: %ld", user.name, user.age).data);
        int64_t result = add(10, 20);
        printf("%.*s\n", (int)kl_interp("10 + 20 = %ld", result).len, kl_interp("10 + 20 = %ld", result).data);
    return 0;
}

int32_t add(int32_t a, int32_t b) {
        return (a + b);
}
