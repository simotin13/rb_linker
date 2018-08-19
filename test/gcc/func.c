#include <stdio.h>

extern int ext_number;
extern char *ext_srt;
extern int ext_add(int , int);
int func_local() {
	return 0;
}

int call_ext_add() {
	int result;
	result = ext_add(1, 2);
}

int call_local() {
	int ret;
	ret = func_local();
	return ret;
}

void set_ext_number(void)
{
    // set extern variable
    ext_number = 0x1234;
}

void loop(void)
{
    int a = 0;
    while(1)
    {
      if (a % 10 == 0) {
          printf("10");
	  }
      a++;
    }
}
