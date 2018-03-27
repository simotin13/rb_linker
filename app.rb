#!/usr/local/bin/ruby

require "./elf"
if ARGV.length < 1
  puts "input object file."
  exit 1
end

ARGV.each do |filepath|
  elf = ELF.new filepath
  elf.show_elf_header
end
