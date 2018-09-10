#include <stdio.h>
#include "ruby.h"
#include "elf32lib.h"

// For mmap
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

VALUE rb_elfModule;
VALUE rb_cElf32;
VALUE rb_cElf32_Ehdr;
VALUE rb_cElf32_Sym;

static VALUE elf32_initialize(VALUE self, VALUE filepath);
static VALUE elf32_show_Ehdr(VALUE self);

static void raise_exception(const char *fname, int lnum);
static void dbg_printf(const char *fmt, ...);

static void rb_elf32_free(void *pObj)
{
	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "In..." );
	
	ST_ELF32 *pElf32 = (ST_ELF32 *)pObj;
    elf32_munmapFile(pElf32, pElf32->length);
	free(pElf32);
	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "Out..." );
	return;
}
static size_t rb_elf32_size(const void *pObj)
{
	ST_ELF32 *pElf32 = (ST_ELF32 *)pObj;
	return sizeof(ST_ELF32) + pElf32->length;
}

static const rb_data_type_t rb_elf32_type = {
    "ELF/Elf32",
    {
		0,							// dmark
    	rb_elf32_free,				// dfree
    	rb_elf32_size,				// dsize
    	0,							// reserved
    },
    0,								// parent
	0,								// for user
	RUBY_TYPED_FREE_IMMEDIATELY,	// free when unused.
};

static VALUE elf32_alloc(VALUE klass)
{
	ST_ELF32 *pObj;
	return TypedData_Make_Struct(klass, ST_ELF32, &rb_elf32_type, pObj);
}

static VALUE elf32_initialize(VALUE self, VALUE filepath)
{
	int ret;
	ST_ELF32 *pElf32;
	Check_Type( filepath, T_STRING );

	TypedData_Get_Struct(self, ST_ELF32, &rb_elf32_type, pElf32);
	ret = elf32_mmapFile(StringValuePtr(filepath), PROT_READ, MAP_PRIVATE, 0, (void *)&pElf32->pAddr, &pElf32->length);
	if (ret < 0) {
		raise_exception(__FUNCTION__, __LINE__);
	}
	return Qnil;
}

static VALUE elf32_show_Ehdr(VALUE self)
{
	ST_ELF32 *pElf32;
	TypedData_Get_Struct(self, ST_ELF32, &rb_elf32_type, pElf32);
	elf32_showEhdr( (Elf32_Ehdr *)pElf32->pAddr );
	return Qnil;
}

static VALUE elf32_merge_symbols(VALUE self, VALUE arg)
{
	#if 0
	ST_ELF32 *pSelf, *pArg;
	Elf32_Shdr *pSelfShdr;
	Elf32_Shdr *pArgShdr;
	Elf32_Shdr *pArgStrShdr;	// 結合オブジェクト文字列セクション
	uint8_t *pSelfSymtab;
	Elf32_Sym *pArgSymtab;
	uint32_t idx;
	size_t size;
	int ret;

	TypedData_Get_Struct(self, ST_ELF32, &rb_elf32_type, pSelf);
	TypedData_Get_Struct(arg, ST_ELF32, &rb_elf32_type, pArg);

	ret = elf32_searchShdr(pSelf->pAddr, ".symtab", &pSelfShdr, &idx);
	pSelfSymtab = (pSelf->pAddr + pSelfShdr->sh_offset);
	// .symtabの最後へ移動
	pSelfSymtab += pSelfShdr->sh_size;

	// 結合するオブジェクトのシンボルテーブル位置へ移動
	ret = elf32_searchShdr(pArg->pAddr, ".symtab", &pArgShdr, &idx);
	pArgSymtab = (Elf32_Sym *)(pArg->pAddr + pArgShdr->sh_offset);
	size = pArgShdr->sh_size;

	// 全てを先に結合してからあとでチェックしてもよい
	memcpy(pSelfSymtab, pArgShdr, sizeof(Elf32_Sym));
	pSelfSymtab += sizeof(Elf32_Sym);
	while(0 < size) {
		// やること
		// シンボルに対応する文字列をコピー
		//   →シンボルのタイプをチェックすること
		switch(pArgShdr->sh_type) {
		case fff:
			ret = elf32_searchShdr(pArg->pAddr, ".symtab", &pArgStrShdr, &idx);
			break;
		default:
			break;
		}
	}
	#endif

	return Qnil;
}
static void raise_exception(const char *fname, int lnum)
{
	// TODO error handle
	rb_exc_raise(rb_str_new2("TODO Exception!!"));
}

void Init_elf32( void ) {

	rb_elfModule = rb_define_module( "ELF" );
	rb_cElf32 = rb_define_class_under( rb_elfModule, "Elf32" , rb_cObject );
    rb_define_alloc_func(rb_cElf32, elf32_alloc);
	rb_define_method( rb_cElf32, "initialize", elf32_initialize, 1 );
	rb_define_method( rb_cElf32, "show_Ehdr", elf32_show_Ehdr, 0 );
	rb_define_method( rb_cElf32, "merge_symbols", elf32_merge_symbols, 1);
	return;
}

static void dbg_printf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "[DEBUG] ");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr, "\n");
    va_end(ap);
	return;
}
