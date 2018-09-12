require "./elf32"

elf32 = ELF::Elf32.new("hoge.o")
elf32.show_Ehdr
elf32.symtab



