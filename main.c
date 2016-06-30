#include <stdio.h>

int main(void) {
    int hoge = 0x12345678;
	unsigned long long num_64 = 0x123456789ABCDEF7;
	char *p;
	p = (char*)&hoge;
printf("%x,%x,%x,%x\n", p[0], p[1], p[2], p[3]);

printf("size:%d\n",sizeof(num_64));

	p = (char*)&num_64;
printf("%x, %x, %x, %x, %x, %x, %x, %x\n", p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);
return 0;

}

