#ifndef __ELF32LIB_H__
#define __ELF32LIB_H__
#include <elf.h>
typedef struct {
	uint8_t *pAddr;
	size_t	length;
}ST_ELF32;

extern void elf32_showElf32_Ehdr(Elf32_Ehdr *pEhdr);
extern int	elf32_searchShdr(uint8_t *pAddr, char *name, Elf32_Shdr **pShdr, uint32_t *pIdx);

extern void elf32_showEhdr(Elf32_Ehdr *pEhdr);
extern int elf32_mmapFile(char *filepath, int prot, int flags, int offset, void** pAddr, size_t *pLength);
extern int elf32_munmapFile(void *pAddr, size_t length);
extern int elf32_mremap(void *pOldAddr, size_t oldSize, size_t newSize, int flags, size_t *pLength);

#endif // __ELF32LIB_H__
