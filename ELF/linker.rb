require 'elf'

module ELF
	class Linker

	  def check_elf_header elf_objects
	    # check ELF Header of each objects
	    true
	  end

		# ==========================================================================
		# write program headers
		# ==========================================================================
	  def write_elf_header(link_f, elf_object)
			wsize = 0
	    elf_header = elf_object.ident
	    wsize += link_f.write(elf_header.pack("C*"))
	    elf_class = elf_object.elf_class
	    endian = elf_object.ident[ELF_IDENT_OFFSET_ENDIAN] == ELF_LITTLE_ENDIAN

	    case elf_class
	    when ELF_CLASS_ELF32
		    wsize += link_f.write(elf_object.elf_type.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_machine.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_version.to_bin32(endian))
		    wsize += link_f.write(elf_object.elf_entry.to_bin32(endian))
		    wsize += link_f.write(elf_object.elf_program_h_offset.to_bin32(endian))
		    wsize += link_f.write(elf_object.elf_section_h_offset.to_bin32(endian))
		    wsize += link_f.write(elf_object.elf_flags.to_bin32(endian))
		    wsize += link_f.write(elf_object.elf_h_size.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_program_h_size.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_program_h_num.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_section_h_size.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_section_h_num.to_bin16(endian))
		    wsize += link_f.write(elf_object.elf_section_name_idx.to_bin16(endian))
	    when ELF_CLASS_ELF64
				throw "not implemented"
	    else
				throw "unexpected class"
	    end
			wsize
	  end

		# ==========================================================================
		# write program header
		# ==========================================================================
		def write_prog_header(link_f, program_header)
			wsize = 0
			wsize += link_f.write(program_header[:p_type].to_bin32)
			wsize += link_f.write(program_header[:p_offset].to_bin32)
			wsize += link_f.write(program_header[:p_vaddr].to_bin32)
			wsize += link_f.write(program_header[:p_paddr].to_bin32)
			wsize += link_f.write(program_header[:p_filesz].to_bin32)
			wsize += link_f.write(program_header[:p_memsz].to_bin32)
			wsize += link_f.write(program_header[:p_flags].to_bin32)
			wsize += link_f.write(program_header[:p_align].to_bin32)
			wsize
		end

		# ==========================================================================
		# write section header
		# ==========================================================================
		def write_section_header(link_f, section_info)
			wsize = 0
			wsize += link_f.write(section_info[:name_idx].to_bin32)
			wsize += link_f.write(section_info[:type].to_bin32)
			wsize += link_f.write(section_info[:flags].to_bin32)
			wsize += link_f.write(section_info[:va_address].to_bin32)
			wsize += link_f.write(section_info[:offset].to_bin32)
			wsize += link_f.write(section_info[:size].to_bin32)
			wsize += link_f.write(section_info[:related_section_idx].to_bin32)
			wsize += link_f.write(section_info[:info].to_bin32)
			wsize += link_f.write(section_info[:addr_align].to_bin32)
			wsize += link_f.write(section_info[:entry_size].to_bin32)
			wsize
		end
	end
end
