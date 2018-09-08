#ifndef __ELF32LIB_H__
#define __ELF32LIB_H__
#include <elf.h>
typedef struct {
	uint8_t *pAddr;
	size_t	length;
}ST_ELF32;

extern void getNames(Elf32_Ehdr *pEhdr);
extern void show_Elf32_Ehdr(Elf32_Ehdr *pEhdr);
extern int search_Shdr(uint8_t *pAddr, char *name, Elf32_Shdr **pShdr, uint32_t *pIdx);

extern int mmap_file(char *filepath, int prot, int flags, int offset, void** pAddr, size_t *length);
int munmap_file(void *pAddr, size_t length);

#endif // __ELF32LIB_H__
