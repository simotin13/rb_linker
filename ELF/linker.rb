require 'elf'

module ELF
	class Linker

	  def check_elf_header elf_objects
	    # check ELF Header of each objects
	    true
	  end

	  def link filepath, elf_objects
	    check_elf_header(elf_objects)

	    elf_first = elf_objects.first
	    elf_objects = elf_objects
	    link_f = open(filepath, "wb")
	    elf_objects.each do |elf_object|
	      text = elf_object.get_section_data(".text")
	      link_f.write(text.pack("C*"))
	    end


	    out_elf_header(link_f, elf_first, elf_objects)

	  end

	  def out_elf_header link_f, elf_first, elf_objects
	    elf_header = elf_first.ident
	    #elf_header << elf_first.ident
	    link_f.write(elf_header.pack("C*"))
	  end
	end
end
