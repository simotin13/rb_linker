require 'elf'
require 'linker'
module ELF
	class RXLinker < Linker

	  def check_elf_header elf_objects
	    # check ELF Header of each objects
	    true
	  end

	  def link filepath, elf_objects
	    check_elf_header(elf_objects)

	    elf_first = elf_objects.first
	    elf_objects = elf_objects
	    link_f = open(filepath, "wb")
			section_size = 0

			# P section (instruction code)
			text_section = []
	    elf_objects.each do |elf_object|
	    	text_sect = elf_object.get_section_data("P")
	    	puts text_sect
	      text_section.concat(text_sect)
	    end

			# ELF header
	    out_elf_header(link_f, elf_first, elf_objects)

			# text section
			link_f.write(text_section.pack("C*"))

			# Section Header

	  end
	end
end
