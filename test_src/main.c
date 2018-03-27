#include <stdio.h>

extern int call_local();
extern int call_ext_add();

int main(int argc, char **argv) {
	int ret;
	
	ret = call_local();
	printf("ret:%d\n", ret);

	ret = call_ext_add();
	printf("ret:%d\n", ret);
	return 0;
}
