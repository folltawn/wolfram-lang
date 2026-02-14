// Сгенерировано компилятором Palladium
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

char* __nice_float_to_str(double value) {
  char* buf = malloc(32);
  if (fmod(value, 1.0) == 0.0) {
    sprintf(buf, "%.0f", value);
  } else if (fmod(value * 10, 1.0) == 0.0) {
    sprintf(buf, "%.1f", value);
  } else if (fmod(value * 100, 1.0) == 0.0) {
    sprintf(buf, "%.2f", value);
  } else {
    sprintf(buf, "%.2f", value);
  }
  return buf;
}

char* __int_to_str(int value) {
  char* buf = malloc(32);
  sprintf(buf, "%d", value);
  return buf;
}

char* __float_to_str(double value) {
  return __nice_float_to_str(value);
}

char* __bool_to_str(bool value) {
  return value ? "true" : "false";
}

char* __str_to_str(char* value) {
  return value;
}

#define __to_str(x) _Generic((x), \
  int: __int_to_str, \
  double: __float_to_str, \
  bool: __bool_to_str, \
  char*: __str_to_str \
)(x)

int main() {
  const char* x = "Hello World";
  printf("%s\n", x);
  return 0;
}
