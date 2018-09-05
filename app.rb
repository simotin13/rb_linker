#!/usr/bin/ruby
$LOAD_PATH.push("./ELF")
require "elf"
require "elf_object"
require "rx_linker"

if ARGV.length < 1
  puts "input .clnk filepath."
  exit 1
end

linker = ELF::RXLinker.new
linker.link "test/led/sakura2.clnk"
