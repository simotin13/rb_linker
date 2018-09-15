#include <stdio.h>
#include <string.h>
#include <elf.h>

// For mmap
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#define PAGE_SIZE (1024 *4)

static uint8_t *elf32_getStrTab(uint8_t *pAddr, size_t *pSize)
{
	Elf32_Ehdr *pEhdr;
	Elf32_Shdr *pShdr;
	Elf32_Shdr *pStrSh;

	pEhdr = (Elf32_Ehdr *)pAddr;
	pShdr = (Elf32_Shdr *)(pAddr + pEhdr->e_shoff);
	printf("pEhdr->e_shstrndx:%d\n", pEhdr->e_shstrndx);
	pStrSh = &pShdr[pEhdr->e_shstrndx];
	*pSize = pStrSh->sh_size;
	return (uint8_t *)(pAddr + pStrSh->sh_offset);
}

static int elf32_getSectionNameOffset(uint8_t *pAddr, const char *name, size_t *pOffset)
{
	size_t size;
	size_t sLen;
	uint8_t *pStr;
	size_t offset;
	offset = 0;

	pStr = elf32_getStrTab(pAddr, &size);
	printf("size:%zu\n", size);
	while(0 < size) {
		sLen = strlen((const char *)pStr);
		printf("%s, %zu\n", pStr, sLen);
		if (strcmp(name, (const char *)pStr) == 0) {
			*pOffset = offset;
			return 0;
		}

		size -= (sLen + 1);
		pStr += (sLen + 1);
		offset += (sLen + 1);
	}
	return -1;
}

int elf32_searchShdr(uint8_t *pAddr, char *name, Elf32_Shdr **pShdr, uint32_t *pIdx)
{
	int ret;
	int i;
	Elf32_Ehdr *pEhdr;
	Elf32_Shdr *pTmp;
	size_t offset;
	pEhdr = (Elf32_Ehdr *)pAddr;

	ret = elf32_getSectionNameOffset(pAddr, name, &offset);
	if (ret < 0)
	{
		printf("%s not found\n", name);
		return -1;
	}

	pTmp = (Elf32_Shdr *)(pAddr + pEhdr->e_shoff);
	for(i = 0; i < pEhdr->e_shnum; i++) {
		if (pTmp->sh_name == offset) {
			*pIdx = i;
			*pShdr = pTmp;
			return 0;
		}
		pShdr++;
	}

	return -1;
}

void elf32_showEhdr(Elf32_Ehdr *pEhdr)
{
	fprintf(stdout, "Magic Number:[%02X][%c][%c][%c]\n", pEhdr->e_ident[0], pEhdr->e_ident[1], pEhdr->e_ident[2], pEhdr->e_ident[3]);
	fprintf(stdout, "e_machine:%d\n", pEhdr->e_machine);
	fprintf(stdout, "Entry Address:%X\n", pEhdr->e_entry);
	fprintf(stdout, "e_shoff:%d\n", pEhdr->e_shoff);
	fprintf(stdout, "e_shentsize:%d\n", pEhdr->e_shentsize);
	fprintf(stdout, "e_shnum:%d\n", pEhdr->e_shnum);
	fprintf(stdout, "e_shstrndx:%d\n", pEhdr->e_shstrndx);
	fprintf(stdout, "%p\n", pEhdr);
	return;
}

void elf32_showShdr(Elf32_Shdr *pEhdr)
{
	return;
}

void elf32_showSym(Elf32_Sym *pSym)
{
	return;
}
void elf32_showPhdr(Elf32_Phdr *pPhdr)
{
	return;
}
void elf32_showRel(Elf32_Rel *pRel)
{
	return;
}
void elf32_showRela(Elf32_Rela *pRela;)
{
	return;
}

int elf32_munmapFile(void *pAddr, size_t length)
{
	return munmap(pAddr, length);
}

int elf32_mmapFile(char *filepath, int prot, int flags, int offset, void** pAddr, size_t *pLength)
{
	struct stat r_stat;
	int fd;
	size_t map_size = 0;

	fd = open(filepath, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "fopen failed\n");
		exit(-1);
	}

	fstat(fd, &r_stat);

	//map_size = r_stat.st_size + PAGE_SIZE;
	map_size = r_stat.st_size;
	*pAddr = mmap(NULL, map_size, prot, flags, fd, offset);
	if (*pAddr == MAP_FAILED) {
		fprintf(stderr, "mmap %s failed\n", filepath);
		return -1;
	}

	*pLength = map_size;

	close(fd);
	return 0;
}

int elf32_mremap(void *pOldAddr, size_t oldSize, size_t newSize, int flags, size_t *pLength)
{
	// TODO
	#if 0
	uint8_t *pMapAddr;
	pMapAddr = mremap(pOldAddr, oldSize, newSize, flags);
	if (*pMapAddr == MAP_FAILED) {
		fprintf(stderr, "mremap failed\n");
		return -1;
	}
	#endif
	return 0;
}
