#include <stdio.h>
#include <string.h>
#include <elf.h>

// For mmap
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

static uint8_t *getStrTab(uint8_t *pAddr, size_t *pSize)
{
	Elf32_Ehdr *pEhdr;
	Elf32_Shdr *pShdr;
	Elf32_Shdr *pStrSh;

	pEhdr = (Elf32_Ehdr *)pAddr;
	pShdr = (Elf32_Shdr *)(pAddr + pEhdr->e_shoff);
	pStrSh = &pShdr[pEhdr->e_shstrndx];
	*pSize = pStrSh->sh_size;
	return (uint8_t *)(pAddr + pStrSh->sh_offset);
}

static int getSectionNameOffset(uint8_t *pAddr, const char *name, size_t *pOffset)
{
	size_t size;
	size_t sLen;
	uint8_t *pPos;
	size_t offset;
	offset = 0;
	fprintf( stderr, "%s %d %s %s\n", __FILE__, __LINE__, __FUNCTION__, "In..." );

	pPos = getStrTab(pAddr, &size);
	printf("size:%d\n", size);
	while(0 < size) {
		sLen = strlen(pPos);
		printf("%s, %d\n", pPos, sLen);
		if (strcmp(name, pPos) == 0) {
			*pOffset = offset;
			return 0;
		}

		size -= (sLen + 1);
		pPos += (sLen + 1);
		offset += (sLen + 1);
	}
	return -1;
}


int search_Shdr(uint8_t *pAddr, char *name, Elf32_Shdr **pShdr, uint32_t *pIdx)
{
	int ret;
	int i;
	Elf32_Ehdr *pEhdr;
	Elf32_Shdr *pTmpShdr;
	size_t offset;
	pEhdr = (Elf32_Ehdr *)pAddr;

	ret = getSectionNameOffset(pAddr, ".symtab", &offset);
	if (ret < 0)
	{
		printf(".symtab not found\n");
		return -1;
	}

	Elf32_Shdr *pTmp = (Elf32_Shdr *)(pAddr + pEhdr->e_shoff);
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


void getNames(uint8_t *pAddr)
{
}

Elf32_Sym *getSymTbl(Elf32_Ehdr *pEhdr)
{
}

void show_Elf32_Ehdr(Elf32_Ehdr *pEhdr)
{
	fprintf(stdout, "Magic Number:[%02X][%c][%c][%c]\n", pEhdr->e_ident[0], pEhdr->e_ident[1], pEhdr->e_ident[2], pEhdr->e_ident[3]);
	fprintf(stdout, "Entry Address:%X\n", pEhdr->e_entry);
	return;
}

void show_Elf32_Shdr(Elf32_Shdr *pEhdr)
{
	return;
}

void show_Elf32_Sym(Elf32_Sym *pSym)
{
	return;
}
void show_Elf32_Phdr(Elf32_Phdr *pPhdr)
{
	return;
}
void show_Elf32_Rel(Elf32_Rel *pRel)
{
	return;
}
void show_Elf32_Rela(Elf32_Rela *pRela;)
{
	return;
}

int munmap_file(void *pAddr, size_t length)
{
	return munmap(pAddr, length);
}

int mmap_file(char *filepath, int prot, int flags, int offset, void** pAddr)
{
	struct stat r_stat;
	int fd;
	uint8_t *pMapAddr;

	fd = open(filepath, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "fopen failed\n");
		exit(-1);
	}

	fstat(fd, &r_stat);
	*pAddr = mmap(NULL, r_stat.st_size, prot, flags, fd, offset);
	if (*pAddr == MAP_FAILED) {
		fprintf(stderr, "mmap %s failed\n", filepath);
		return -1;
	}

	close(fd);
	return 0;
}
