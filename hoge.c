static int s_num = 0x1234;
int g_num = 0x4567;

// 未解決のシンボル
int link_function(void);

static int s_hoge(void) {
	return 0x12;
}

int g_hoge(void) {
	return 0x34;
}

void caller(void) {
	int ret;
	ret = link_function();
	return;
}
