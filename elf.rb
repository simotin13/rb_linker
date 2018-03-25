require './monkey_patch'
require './machine_arch_list'

class ELF
	SIZE_IDENT			= 16
	SIZE_HALF_WORD	= 2
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
		@sh_idx_map = {}				# セクションヘッダインデックスマップ
		read_elf_header
	end

	def initialize_section_idx_map
		sec_idx = 0
		while sec_idx < @e_shnum
			sec_pos = @e_shoff + (sec_idx * @sh_size)
			section = @bin[sec_pos, @sh_size]
			sec_idx += 1

			# .shstrtabにおけるセクション名のオフセット位置を取得
			name_offset = section[0, SIZE_WORD].to_i
			name = @names_section[name_offset, @names_sec_length].c_str

			# セクションヘッダのインデックスを設定
			@sh_idx_map[name] = sec_idx
		end
	end

	# 指定されたセクション名のセクションヘッダ情報を取得
	def get_section_header section_name
		sec_idx = @sh_idx_map[section_name]

		# 該当セクションなし
		throw "no such section" if sec_idx.nil?

		sec_pos = @e_shoff + (sec_idx * @sh_size)
		@bin[sec_pos, @sh_size]
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
		initialize_section_idx_map
		debug_section = get_section_header ".debug_info"
		show_section_header debug_section
	end

	# セクションヘッダの内容を出力
	def show_section_header section_header
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
		@pos_phsize_offset = @pos_ehsize + SIZE_HALF_WORD
		@pos_phnum_offset = @pos_phsize_offset + SIZE_HALF_WORD
		@pos_shsize_offset = @pos_phnum_offset + SIZE_HALF_WORD
		@pos_shnum_offset = @pos_shsize_offset + SIZE_HALF_WORD
		@pos_shstrndx = @pos_shnum_offset + SIZE_HALF_WORD

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
		@eh_size = @bin[@pos_ehsize, SIZE_HALF_WORD].to_i
		puts "elf header size			:#{@eh_size}"
	end

	def read_ph_size
		@ph_size = @bin[@pos_phsize_offset, SIZE_HALF_WORD].to_i
		puts "program header size		:#{@ph_size}"
	end

	def read_ph_num
		@e_phnum = @bin[@pos_phnum_offset, SIZE_HALF_WORD].to_i
		puts "program header entry number	:#{@e_phnum}"
	end

	def read_sh_size
		@sh_size = @bin[@pos_shsize_offset, SIZE_HALF_WORD].to_i
		puts "section header size 		:#{@sh_size}"
	end

	def read_sh_num
		@e_shnum = @bin[@pos_shnum_offset, SIZE_HALF_WORD].to_i
		puts "section header entry number	:#{@e_shnum}"
	end

	def read_shs_idx
		 @shs_idx = @bin[@pos_shstrndx, SIZE_HALF_WORD].to_i
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
		@names_sec_length = sh_name[size_pos, sh_size_size].to_i
		puts "sh_offset:#{sh_offset.to_h}, names_section_length:#{@names_sec_length.to_h}"
		@names_section = @bin[sh_offset, @names_sec_length]
		pos = 0
		until @names_sec_length <= pos do
			name = @names_section[pos, @names_sec_length].c_str
			puts name
			pos += name.length
			pos += 1
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
