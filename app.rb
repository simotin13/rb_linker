#!/usr/local/bin/ruby
$LOAD_PATH.push("./")
$LOAD_PATH.push("./ELF")
require "elf"
require "elf_object"
require "rx_linker"
require "elf32"

if ARGV.length < 1
  puts "input .clnk filepath."
  exit 1
end

linker = ELF::RXLinker.new
linker.link ARGV[0]
