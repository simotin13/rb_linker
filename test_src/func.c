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
