#!/usr/local/bin/ruby

require "./elf"
if ARGV.length < 1
  puts "input object file."
  exit 1
end

elf = ELF.new
elf.load ARGV[0]

elf.show_elf_header
