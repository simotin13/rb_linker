$LOAD_PATH.push("./")
$LOAD_PATH.push("../../")
$LOAD_PATH.push("../../ELF")
require "ELF/elf_object.rb"
require "elf32"

elf_object = ELF::ElfObject.new("./resetprg.obj")
elf_object.section_h_map.each_pair do |section_name, section_info|
  if section_name == ".relaPResetPRG"
    rela_bin = elf_object.get_section_data(section_name)
    rela_list = ELF::Elf32.to_relatab(rela_bin)
    rela_list.each do |rela|
      puts "r_info:#{rela.r_info.to_h}"
      puts "idx:#{rela.symbol_idx}"
      puts "type:#{rela.type}"
      rela.symbol_idx = 3
      rela.type = 14
      puts "r_info:#{rela.r_info.to_h}"
      puts "idx:#{rela.symbol_idx}"
      puts "type:#{rela.type}"
    end
  end
end
