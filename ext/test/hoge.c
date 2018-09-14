extern int ext_val;
extern int ext_hoge;
static int *pHoge = &ext_hoge;
int hoge()
{
    return 3 + ext_val;
}
