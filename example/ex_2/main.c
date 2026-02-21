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
  char*: __str_to_str, \
  const char*: __str_to_str \
)(x)

int main() {
  const char* msg = "Test";
  int count = 42;
  double pi = 3.14;
  char __temp_1[1024];
  __temp_1[0] = '\0';
  strcpy(__temp_1, "Message: ");
  strcat(__temp_1, __to_str(msg));
  printf("%s\n", __temp_1);
  char __temp_2[1024];
  __temp_2[0] = '\0';
  strcpy(__temp_2, "Count: ");
  strcat(__temp_2, __to_str(count));
  printf("%s\n", __temp_2);
  char __temp_3[1024];
  __temp_3[0] = '\0';
  strcpy(__temp_3, "Pi: ");
  strcat(__temp_3, __to_str(pi));
  printf("%s\n", __temp_3);
  char __temp_4[1024];
  __temp_4[0] = '\0';
  strcpy(__temp_4, "Combined: ");
  strcat(__temp_4, __to_str(msg));
  strcat(__temp_4, " - ");
  strcat(__temp_4, __to_str(count));
  strcat(__temp_4, " - ");
  strcat(__temp_4, __to_str(pi));
  printf("%s\n", __temp_4);
  if ((count == 42)) {
    printf("%s\n", __to_str(count));
  }
  else {
    printf("%s\n", __to_str(count));
  }
  return 0;
}
