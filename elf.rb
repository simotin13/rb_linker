require './monkey_patch'
require './machine_arch_list'

class ELF
	SIZE_IDENT			= 16
	SIZE_HARF_WORD	= 2
	SIZE_WORD				= 4
	SIZE_XWORD			= 8
	SIZE_ADDR_32		= 4
	SIZE_ADDR_64		= 8

	def initialize filepath
		@bin = File.binread(filepath).unpack("C*")
		unless is_elf?
			throw "This is not ELF Format File"
		end
		@pos_entry = 24			# e_entry offset pos
		read_elf_header
	end

	def read_elf_header
		read_elf_class
		read_endian
		read_elf_version
		read_OS_ABI
		read_file_type
		read_file_version
		read_machie_arch
		read_entry
		read_ph_offset
		read_sh_offset
		read_eflags
		read_eh_size
		read_ph_size
		read_ph_num
		read_sh_size
		read_sh_num
		read_shs_idx
		read_sections
	end

	def read_elf_class
		print "ELF Class			:"
		case @ident[4].ord
		when 1
			@elf_class = :class_32bit
			@addr_size = 4
			puts "32bit Object"
		when 2
			@elf_class = :class_64bit
			@addr_size = 8
			puts "64bit Object"
		else
			puts "Invalid Class"
		end
	end

	def read_endian
		print "Endian				:"
		case @ident[5].ord
		when 1
			puts "Little Endian"
		when 2
			puts "Big Endian"
		else
			puts "Invalid Endian"
		end
	end

	def read_elf_version
		puts "ELF Version			:#{@ident[6].ord}"
	end

	def read_OS_ABI
		print "OS ABI				:"
		case @ident[7].ord
		when 0
			puts "UNIX - System V"
		when 3
			puts "Linux"
		else
			# TODO
		end
	end

	def read_file_type
		@e_type = @bin[16, 2]
		puts "File Type			:#{@e_type.to_i}"
	end

	def read_machie_arch
		@e_machine = @bin[18, 2]
		puts "Machine Archtecture		:#{@e_machine.to_i} [#{ELF_MACHINE_ARCH_LIST[@e_machine.to_i]}]"
	end

	def read_file_version
		@elf_version = @bin[20, 4]
		puts "ELF File Version		:#{@elf_version.to_i}"
	end

	def read_entry
		@e_entry = @bin[@pos_entry, @addr_size].to_i
		@pos_phoff = @pos_entry   + @addr_size
		@pos_shoff = @pos_phoff  + @addr_size
		@pos_eflags = @pos_shoff + @addr_size
		@pos_ehsize = @pos_eflags + SIZE_WORD
		@pos_phsize_offset = @pos_ehsize + SIZE_HARF_WORD
		@pos_phnum_offset = @pos_phsize_offset + SIZE_HARF_WORD
		@pos_shsize_offset = @pos_phnum_offset + SIZE_HARF_WORD
		@pos_shnum_offset = @pos_shsize_offset + SIZE_HARF_WORD
		@pos_shstrndx = @pos_shnum_offset + SIZE_HARF_WORD

		puts "entry point address		:#{@e_entry.to_h}"
	end

	def read_ph_offset
		@e_phoff = @bin[@pos_phoff, @addr_size].to_i
		puts "program header offset address	:#{@e_phoff.to_h}"
	end

	def read_sh_offset
		@e_shoff = @bin[@pos_shoff, @addr_size].to_i
		puts "section header offset address	:#{@e_shoff.to_h}(#{@e_shoff})"
	end

	def read_eflags
			eflag = @bin[@pos_eflags, SIZE_WORD].to_i
			puts "e_flags				:#{eflag.to_h}(Not Used)"
	end

	def read_eh_size
		@eh_size = @bin[@pos_ehsize, SIZE_HARF_WORD].to_i
		puts "elf header size			:#{@eh_size}"
	end

	def read_ph_size
		@ph_size = @bin[@pos_phsize_offset, SIZE_HARF_WORD].to_i
		puts "program header size		:#{@ph_size}"
	end

	def read_ph_num
		@e_phnum = @bin[@pos_phnum_offset, SIZE_HARF_WORD].to_i
		puts "program header entry number	:#{@e_phnum}"
	end

	def read_sh_size
		@sh_size = @bin[@pos_shsize_offset, SIZE_HARF_WORD].to_i
		puts "section header size 		:#{@sh_size}"
	end

	def read_sh_num
		@e_shnum = @bin[@pos_shnum_offset, SIZE_HARF_WORD].to_i
		puts "section header entry number	:#{@e_shnum}"
	end

	def read_shs_idx
		 @shs_idx = @bin[@pos_shstrndx, SIZE_HARF_WORD].to_i
		 puts "section name strings section	:#{@shs_idx}"
	end

	def read_sections
		# セクション名保持セクションのオフセット取得
		@s_names_offset = @e_shoff + ( (@shs_idx) * @sh_size)
		puts "s_names_offset:#{@s_names_offset.to_h}"
		sh_name = @bin[@s_names_offset, @sh_size]

		# セクションのオフセット位置 格納位置
		# sh_name(4) + sh_type(4) + sh_flags(4) + sh_addr(addr_size)
		name_pos = 0
		type_pos = name_pos + SIZE_WORD
		sh_type = sh_name[type_pos, SIZE_WORD].to_i
		flags_pos = type_pos + SIZE_WORD
		sh_flags = sh_name[flags_pos, SIZE_WORD].to_i
		puts "sh_type:#{sh_type}, sh_flags:#{sh_flags}"

		if @elf_class == :class_32bit
			flags_size = SIZE_WORD
			sh_size_size = SIZE_WORD
		else
			flags_size = SIZE_XWORD
			sh_size_size = SIZE_XWORD
		end

		addr_pos = flags_pos + flags_size
		offset_pos = addr_pos + @addr_size
		puts "offset_pos:#{offset_pos}"
		sh_offset = sh_name[offset_pos, @addr_size].to_i
		size_pos = offset_pos + @addr_size
		sh_size = sh_name[size_pos, sh_size_size].to_i
		puts "sh_offset:#{sh_offset.to_h}, sh_size:#{sh_size.to_h}"
		names_section = @bin[sh_offset, sh_size]
		pos = 0
		lengh = names_section.length
		until lengh <= pos do
			name = names_section[pos, lengh].c_str
			puts name
			pos += name.length + 1
		end
	end

	# identのマジックナンバーチェック
	def is_elf?
		@ident = @bin[0, SIZE_IDENT]
		return false if @ident[0] != 0x7F
		return false if @ident[1] != 'E'.ord
		return false if @ident[2] != 'L'.ord
		return false if @ident[3] != 'F'.ord
		true
	end
end

unless ARGV[0].nil?
	ELF.new ARGV[0]
else
	puts "Usage: ruby elf.rb a.out"
end
