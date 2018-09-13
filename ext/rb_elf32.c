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

static void raise_exception(const char *fname, int lnum)
{
	// TODO error handle
	rb_exc_raise(rb_str_new2("TODO Exception!!"));
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

// =============================================================================
// Elf32_Sym
// =============================================================================
static void rb_elf32sym_free(void *pObj)
{
	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "In..." );

	Elf32_Sym *pSym = (Elf32_Sym *)pObj;
	free(pSym);
	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "Out..." );
	return;
}
static size_t rb_elf32sym_size(const void *pObj)
{
	return sizeof(Elf32_Sym);
}

static const rb_data_type_t rb_elf32sym_type = {
    "ELF/Elf32Sym",
    {
		0,							// dmark
    	rb_elf32sym_free,			// dfree
    	rb_elf32sym_size,			// dsize
    	{0},						// reserved
    },
    0,								// parent
	0,								// for user
	RUBY_TYPED_FREE_IMMEDIATELY,	// free when unused.
};

static VALUE elf32sym_alloc(VALUE self)
{
	Elf32_Sym *pObj;
	return TypedData_Make_Struct(self, Elf32_Sym, &rb_elf32sym_type, pObj);
}

static VALUE rb_elf32sym_new(void)
{
	return elf32sym_alloc(rb_cElf32_Sym);
}

static VALUE elf32sym_Sym(const Elf32_Sym const *pSym)
{
	VALUE obj;
	Elf32_Sym *ptr;
	obj = rb_elf32sym_new();
	TypedData_Get_Struct(obj, Elf32_Sym, &rb_elf32sym_type, ptr);
	memcpy(ptr, pSym, sizeof(Elf32_Sym));
	return obj;
}
static VALUE elf32sym_show_symtab(VALUE self, VALUE ary)
{
	int i;
	int len;
	Elf32_Sym *pSym;
	VALUE sh_sym;

	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "In..." );
	Check_Type( ary, T_ARRAY );
	len = RARRAY_LEN(ary);
	for(i = 0; i < len; i++) {
		sh_sym = rb_ary_entry(ary, i);
		TypedData_Get_Struct(sh_sym, Elf32_Sym, &rb_elf32sym_type, pSym);
		fprintf(stdout, "st_name:[%d], ", pSym->st_name);
		fprintf(stdout, "st_value:[%d], ", pSym->st_value);
		fprintf(stdout, "st_size:[%d], ", pSym->st_size);
		fprintf(stdout, "st_info:[%d], ", pSym->st_info);
		fprintf(stdout, "st_other:[%d], ", pSym->st_other);
		fprintf(stdout, "st_shndx:[%d]\n", pSym->st_shndx);
	}
	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "Out..." );
	return Qnil;
}

void init_elf32sym(void)
{
	rb_cElf32_Sym = rb_define_class_under( rb_elfModule, "Elf32Sym" , rb_cObject );
    rb_define_alloc_func(rb_cElf32_Sym, elf32sym_alloc);
	rb_define_singleton_method( rb_cElf32_Sym, "show_symtab", elf32sym_show_symtab, 1 );
	return;
}

// =============================================================================
// ELF32 オブジェクト
// =============================================================================
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
    	{0},						// reserved
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

// get .symtab list
static VALUE elf32_get_symtab(VALUE self)
{
	int ret;
	VALUE ary = Qnil;
	ST_ELF32 *pSelf;
	Elf32_Shdr *pShdr;
	uint32_t idx;
	Elf32_Sym *pSymtab;
	size_t size;
	char *pSymtabName;

	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "In..." );
	#if 0
	if (!NIL_P(name)) {
		pSymtabName = ".symtab";
	} else {
		pSymtabName = StringValuePtr(name);
	}
	#endif
	pSymtabName = ".symtab";

	TypedData_Get_Struct(self, ST_ELF32, &rb_elf32_type, pSelf);
	ary = rb_ary_new();
	ret = elf32_searchShdr(pSelf->pAddr, pSymtabName, &pShdr, &idx);
	if (ret < 0) {
		// TODO 
		// Not Found
		return Qnil;
	}

	pSymtab = (Elf32_Sym *)(pSelf->pAddr + pShdr->sh_offset);
	size = pShdr->sh_size;
	while(0 < size)
	{
		rb_ary_push(ary, elf32sym_Sym(pSymtab));
		pSymtab++;
		size -= sizeof(Elf32_Sym);
	}

	dbg_printf( "%s:%d %s %s", __FILE__, __LINE__, __FUNCTION__, "In..." );
	return ary;
}

#if 1
static VALUE elf32_ary2symtab(VALUE self, VALUE ary)
{
	int i,len;
	int count;
	len = RARRAY_LEN(ary);
	uint8_t *pBin;
	Elf32_Sym *pSym;
	VALUE symtab;

	Check_Type( ary, T_ARRAY );
	pBin = malloc(len);

	for(i = 0; i < len; i++) {
		pBin[i] = NUM2CHR(rb_ary_entry(ary, i));
	}

	pSym = (Elf32_Sym *)pBin;
	symtab = rb_ary_new();
	count = len / sizeof(Elf32_Sym);
	for (i = 0; i < count; i++) {
		// new しないと更新されない
//		rb_ary_push(symtab, TypedData_Make_Struct(rb_cElf32_Sym, Elf32_Sym, &rb_elf32sym_type, pSym));
		rb_ary_push(symtab, elf32sym_Sym(pSym));
		pSym++;
	}
	return symtab;
}

#endif
void Init_elf32( void ) {

	rb_elfModule = rb_define_module( "ELF" );
	rb_cElf32 = rb_define_class_under( rb_elfModule, "Elf32" , rb_cObject );
    rb_define_alloc_func(rb_cElf32, elf32_alloc);
	rb_define_method( rb_cElf32, "initialize", elf32_initialize, 1 );
	rb_define_method( rb_cElf32, "show_Ehdr", elf32_show_Ehdr, 0 );
	rb_define_method( rb_cElf32, "symtab", elf32_get_symtab, 0);
	rb_define_singleton_method( rb_cElf32, "to_symtab", elf32_ary2symtab, 1);

	init_elf32sym();
	return;
}

#if 0
static VALUE elf32_merge_symbols(VALUE self, VALUE arg)
{
	ST_ELF32 *pSelf, *pArg;
	Elf32_Shdr *pSelfShdr;
	Elf32_Shdr *pArgShdr;
	Elf32_Shdr *pArgStrShdr;	// 結合オブジェクト文字列セクション
	uint8_t *pSelfSymtab;
	Elf32_Sym *pArgSymtab;
	uint32_t idx;
	size_t size;
	int ret;

	// 実装方針
	// とりあえずシンボルテーブルを全部くっつける
	// タイプを気にせず関連する文字列をコピー
	// →.strtabセクション内でのオフセットは更新する必要がある
	// →先に.strtabを結合し、オブジェクトのオフセット値を保持しておく
	// .symtabを最後に結合し、オフセット値を足して文字列位置を補正する
	// シンボルが必要になる理由
	// リロケーションの時にシンボルテーブルのインデックスで指定されるので
	// 結合できていないとリロケーションができない
	// 順番
	// .strtabのマージ→オブジェクト全体を更新する

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
	return Qnil;
}
#endif
