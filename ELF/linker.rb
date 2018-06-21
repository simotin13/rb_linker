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
			section_size = 0

			# .text section
			text_section = []
	    elf_objects.each do |elf_object|
	    	text_sect = elf_object.get_section_data(".text")
	    	next if text_sect.nil?
	      text_section.concat(elf_object.get_section_data(".text"))
	    end

			# ELF header
	    out_elf_header(link_f, elf_first, elf_objects)

			# text section
			link_f.write(text_section.pack("C*"))

			# Section Header

	  end
		def make_ELF_header elf_header_info
			elf_header = []

			# Magic Number
			elf_header << 0x7F
			elf_header << "ELF"

			elf_header << elf_header_info[:elf_class]
			elf_header << elf_header_info[:elf_class]
			elf_header << elf_header_info[:elf_endian]
			elf_header << ELF_CURRENT_VERSION
			elf_header << elf_header_info[:os_abi]
			elf_header << 0x01	# ABI Version is fixed to 0

			# TODO Endian Array.
			elf_header << elf_header_info[:type]
			elf_header << elf_header_info[:machine]
			elf_header << EV_CURRENT
		end

	  def out_elf_header link_f, elf_first, elf_objects
	    elf_header = elf_first.ident
	    link_f.write(elf_header.pack("C*"))
	    elf_class = elf_first.elf_class
	    endian = elf_first.ident[ELF_IDENT_OFFSET_ENDIAN] == ELF_LITTLE_ENDIAN

	    case elf_class
	    when ELF_CLASS_ELF32
		    link_f.write(elf_first.elf_type.to_bin16(endian))
		    link_f.write(elf_first.elf_machine.to_bin16(endian))
		    link_f.write(elf_first.elf_version.to_bin32(endian))
		    link_f.write(elf_first.elf_entry.to_bin32(endian))
		    link_f.write(elf_first.elf_program_h_offset.to_bin32(endian))
		    link_f.write(elf_first.elf_section_h_offset.to_bin32(endian))
		    link_f.write(elf_first.elf_flags.to_bin32(endian))
		    link_f.write(elf_first.elf_h_size.to_bin16(endian))
		    link_f.write(elf_first.elf_program_h_size.to_bin16(endian))
		    link_f.write(elf_first.elf_program_h_size.to_bin16(endian))
		    link_f.write(elf_first.elf_program_h_num.to_bin16(endian))
		    link_f.write(elf_first.elf_section_h_size.to_bin16(endian))
		    link_f.write(elf_first.elf_section_h_num.to_bin16(endian))
		    link_f.write(elf_first.elf_section_name_idx.to_bin16(endian))
	    when ELF_CLASS_ELF64
	    else
	    end
	  end
	end
end
