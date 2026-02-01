str::const y = "hi";
bool r = true;
float x = 2.71;
int e = 1;

// refactoring example
x = 3.14;
sendln("pi = 3.14");
refactor(x) => str("Hello world!");
sendln(x);