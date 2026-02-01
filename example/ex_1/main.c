// Сгенерировано компилятором Wolfram
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

char* __int_to_str(int value) {
  char* buf = malloc(32);
  sprintf(buf, "%d", value);
  return buf;
}

char* __float_to_str(double value) {
  char* buf = malloc(32);
  sprintf(buf, "%f", value);
  return buf;
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
  const char* y = "hi";
  bool r = true;
  double x = 2.71;
  int e = 1;
  x = 3.14;
  printf("%s\n", __to_str(x) "" "!");
  char* x_str = "Hello world!";
  // x преобразован в строку: x_str
  printf("%s\n", __to_str(x));
  return 0;
}
