/***********************************************************************/
/*                                                                     */
/*  FILE        :Main.c or Main.cpp                                    */
/*  DATE        :Tue, Oct 31, 2006                                     */
/*  DESCRIPTION :Main Program                                          */
/*  CPU TYPE    :                                                      */
/*                                                                     */
/*  NOTE:THIS IS A TYPICAL EXAMPLE.                                    */
/*                                                                     */
/***********************************************************************/
//#include "typedefine.h"

extern int add(int a, int b);

extern int ext_hoge;
void main(void)
{
	int ret;
	ext_hoge = 0x1234;
	ret = add(1,2);
	while(1);
}

#ifdef __cplusplus
void abort(void)
{

}
#endif
