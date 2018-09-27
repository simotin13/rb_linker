require 'monkey_patch'
require 'elf'
require 'machine_arch_list'

module ELF
	class ElfObject
		attr_accessor :bin, :section_h_map, :ident, :elf_class, :elf_endian, :elf_version,
									:os_abi, :elf_type, :elf_machine, :elf_version, :elf_entry,
									:elf_program_h_offset, :elf_section_h_offset, :elf_flags,
									:elf_h_size, :elf_program_h_size, :elf_program_h_num,
									:elf_section_h_size, :elf_section_h_num,
									:elf_section_name_idx, :symbol_table, :rel_sections

		# ==========================================================================
		# constructor
		# ==========================================================================
		def initialize filepath
			read(filepath)
		end

		# ==========================================================================
		# Load Object File
		# - Check if valid ELF and set elf infos.
		# ==========================================================================
		def read filepath
			bin = File.binread(filepath).unpack("C*")
			elf_ident = bin[0, ELF_IDENT_SIZE]

			# check magic number
			unless is_elf? elf_ident
				throw "This is not ELF Format File"
			end

			# Check ELF class
			val = elf_ident[ELF_IDENT_OFFSET_CLASS].ord
			case val
			when ELF_CLASS_ELF32
				@elf_class = ELF_CLASS_ELF32

				# set Address and Offset size for ELF32
				@address_size = ELF_SIZE_ADDR_32
				@offset_size  = ELF_SIZE_OFFSET_32
			when ELF_CLASS_ELF64
				@elf_class = ELF_CLASS_ELF64

				# set Address and Offset size for ELF64
				@address_size = ELF_SIZE_ADDR_64
				@offset_size  = ELF_SIZE_OFFSET_64
			else
				throw "Invalid ELF Class:#{val}"
			end

			# Check Endian
			val = elf_ident[ELF_IDENT_OFFSET_ENDIAN].ord
			case val
			when ELF_LITTLE_ENDIAN, ELF_BIG_ENDIAN
				@elf_endian = val
			else
				throw "Invalid ELF Endian:#{val}"
			end

			# Check ELF Format Version
			val = elf_ident[ELF_IDENT_OFFSET_FORMAT_VERSION].ord
			unless val == 1
				throw "Unsuppoted ELF Format Version:#{val}"
			end
			@elf_version = val

			# Check OS ABI
			val = elf_ident[ELF_IDENT_OFFSET_OS_ABI].ord
			case val
			when OS_ABI_UNIX, OS_ABI_LINUX
				@os_abi = val
			else
				throw "Unsuppoted OS ABI Format:#{val}"
			end

			# Check OS ABI Version
			@os_abi_version = elf_ident[ELF_IDENT_OFFSET_OS_ABI_VERSION]

			@bin = bin
			@ident = elf_ident

			is_little = @elf_endian == ELF_LITTLE_ENDIAN
			case @elf_class
			when ELF_CLASS_ELF32
				@elf_type             = @bin[ELF32_OFFSET_TYPE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_machine          = @bin[ELF32_OFFSET_MACHINE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_version          = @bin[ELF32_OFFSET_VERSION, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_entry            = @bin[ELF32_OFFSET_ENTRY, ELF_SIZE_ADDR_32].to_i(is_little)
				@elf_program_h_offset = @bin[ELF32_OFFSET_PROGRAM_HEADER, ELF_SIZE_OFFSET_32].to_i(is_little)
				@elf_section_h_offset = @bin[ELF32_OFFSET_SECTION_HEADER, ELF_SIZE_OFFSET_32].to_i(is_little)
				@elf_flags            = @bin[ELF32_OFFSET_FLAGS, ELF_SIZE_WORD].to_i(is_little)
				@elf_h_size       		= @bin[ELF32_OFFSET_ELF_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_program_h_size   = @bin[ELF32_OFFSET_PROGRAM_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_program_h_num    = @bin[ELF32_OFFSET_PROGRAM_HEADER_NUM, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_h_size   = @bin[ELF32_OFFSET_SECTION_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_h_num    = @bin[ELF32_OFFSET_SECTION_HEADER_NUM, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_name_idx = @bin[ELF32_OFFSET_SECTION_NAME_IDX, ELF_SIZE_HALF_WORD].to_i(is_little)
			when ELF_CLASS_ELF64
				@elf_type             = @bin[ELF64_OFFSET_TYPE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_machine          = @bin[ELF64_OFFSET_MACHINE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_version          = @bin[ELF64_OFFSET_VERSION, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_entry            = @bin[ELF64_OFFSET_ENTRY, ELF_SIZE_ADDR_64].to_i(is_little)
				@elf_program_h_offset = @bin[ELF64_OFFSET_PROGRAM_HEADER, ELF_SIZE_OFFSET_64].to_i(is_little)
				@elf_section_h_offset = @bin[ELF64_OFFSET_SECTION_HEADER, ELF_SIZE_OFFSET_64].to_i(is_little)
				@elf_flags            = @bin[ELF64_OFFSET_FLAGS, ELF_SIZE_WORD].to_i(is_little)
				@elf_h_size       		= @bin[ELF64_OFFSET_ELF_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_program_h_size   = @bin[ELF64_OFFSET_PROGRAM_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_program_h_num    = @bin[ELF64_OFFSET_PROGRAM_HEADER_NUM, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_h_size   = @bin[ELF64_OFFSET_SECTION_HEADER_SIZE, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_h_num    = @bin[ELF64_OFFSET_SECTION_HEADER_NUM, ELF_SIZE_HALF_WORD].to_i(is_little)
				@elf_section_name_idx = @bin[ELF64_OFFSET_SECTION_NAME_IDX, ELF_SIZE_HALF_WORD].to_i(is_little)
			else
				throw "Invalid ELF Class #{@elf_class}"
			end

			# create section name - section index map.
			initialize_section_h_map

			# DEBUG
			#show_elf_header

			get_program_header
		end

		def get_elf_header
			@bin.slice(0, ELF_SIZE_ELF32_HEADER)
		end

		# ============================================================================
		# Get section header info by section name
		# ============================================================================
		def get_section_header section_name
			sec_idx = @sh_idx_map[section_name]

			# No such section
			return nil if sec_idx.nil?

			sec_pos = @e_shoff + (sec_idx * @sh_size)
			@bin[sec_pos, @sh_size]
		end

		# ============================================================================
		# Get section daat by section name
		# ============================================================================
		def get_section_data section_name
			return nil unless @section_h_map.has_key?(section_name)

			# ファイル中に実体を持たないセクション
			return nil if @section_h_map[section_name][:type] == SH_TYPE_NOBITS

			offset = @section_h_map[section_name][:offset]
			size = @section_h_map[section_name][:size]
			section_data = @bin[offset, size]
		end

		def has_section?(name)
			 !@section_h_map[name].nil?
		end

		# ==========================================================================
		# delete Symbol from symbol table
		# ==========================================================================
		def delete_section_info name
			return if @section_h_map[name].nil?
			idx = @section_h_map[name][:idx]
			@section_h_map.delete(name)
			@section_h_map.each do |name , section_info|
				# セクションのインデックスを更新
				if idx < section_info[:idx]
					tmp_idx = section_info[:idx]
					section_info[:idx] -= 1
					symbol_table.each do |symbol_info|
						# シンボルテーブルのインデックスも合わせて更新
						symbol_info[:st_shidx] -= 1 if symbol_info[:st_shidx] == tmp_idx
					end
				end

				# 参照セクション情報を更新
				section_info[:related_section_idx] -= 1 if idx < section_info[:related_section_idx]
			end
		end

		def related_section_name(src_section_name)
			related_idx = @section_h_map[src_section_name][:related_section_idx]
			related_section = @section_h_map.find{|key,val| val[:idx] == related_idx}
			related_section[1][:name]
		end

	private

		# ============================================================================
		# Show ELF Header info like `readelf -h` format.
		# ============================================================================
		def show_elf_header
			puts "ELF Header:"
			show_magic
			show_elf_class
			show_endian
			show_elf_version
			show_OS_ABI
			show_ABI_version
			show_file_type
			show_machine_arch
			show_file_version
			show_entry_point
			show_program_h_offset
			show_section_h_offset
			show_elf_flags
			show_elf_h_size
			show_program_h_size
			show_program_h_num
			show_section_h_size
			show_section_h_num
			show_section_name_idx
		end

		# ============================================================================
		# Show ELF Magic Number
		# ============================================================================
		def show_magic
			puts "  Magic:   #{@ident.hex_dump(false, false)}"
		end

		# ============================================================================
		# Show ELF Class Info
		# ============================================================================
		def show_elf_class
			class_str = ""
			case @elf_class
			when ELF_CLASS_ELF32
				class_str = "ELF32"
			when ELF_CLASS_ELF32
				class_str = "ELF64"
			else
				class_str = "Invalid Class"
			end
			puts "  Class:                             #{class_str}"
		end

		# ============================================================================
		# Show Endian Info
		# ============================================================================
		def show_endian
			endian_str = ""
			case @elf_endian
			when ELF_LITTLE_ENDIAN
				endian_str = "2's complement, little endian"
			when ELF_BIG_ENDIAN
				endian_str = "2's complement, big endian"
			else
				endian_str = "Invalid Endian"
			end
			puts "  Data:                              #{endian_str}"
		end

		# ============================================================================
		# Show ELF Version Info
		# ============================================================================
		def show_elf_version
			ver_str = "#{@elf_version}"
			ver_str += " (current)" if @elf_version == 1
			puts "  Version:                           #{ver_str}"
		end

		# ============================================================================
		# Show OS ABI Info
		# ============================================================================
		def show_OS_ABI
			abi_str = ""
			case @os_abi
			when :OS_ABI_UNIX
				abi_str = "UNIX - System V"
			when :OS_ABI_LINUX
				abi_str = "Linux"
			else
				abi_str = "undefined OS ABI"
			end
			puts  "  OS/ABI:                            #{abi_str}"
		end

		def show_ABI_version
			 puts "  ABI Version:                       #{@os_abi_version}"
		end

		# ============================================================================
		# Show ELF File Type Info
		# ============================================================================
		def show_file_type
			str = ""
			case @elf_type
			when ELF_ET_REL
				str = "REL (Relocatable file)"
		 	when ELF_ET_EXEC
				str = "EXEC (Executable file)"
			when ELF_ET_DYN
				str = "DYN (Shared object file)"
			when ELF_ET_CORE
				str = "CORE (Core file)"
			else
				str = "Invalid ELF Type #{@elf_type}"
			end
			puts "  Type:                              #{str}"
		end

		# ============================================================================
		# Show ELF Machine Archtecture Info
		# ============================================================================
		def show_machine_arch
			puts "  Machine:                           #{ELF_MACHINE_ARCH_LIST[@elf_machine.to_i]} (#{@elf_machine.to_i})"
		end

		# ============================================================================
		# Show Entry Point Address
		# ============================================================================
		def show_entry_point
			puts "  Entry point address:               #{@elf_entry.to_h}"
		end

		# ============================================================================
		# Show ELF File Version
		# ============================================================================
		def show_file_version
			puts "  Version:                           #{@elf_version.to_h}"
		end

		# ============================================================================
		# Show Program Header info
		# ============================================================================
		def show_program_h_offset
			puts "  Start of program headers:          #{@elf_program_h_offset.to_h} (bytes into file)"
		end

		# ============================================================================
		# Show Section Header info
		# ============================================================================
		def show_section_h_offset
			puts "  Start of section headers:          #{@elf_section_h_offset} (bytes into file)"
		end

		# ============================================================================
		# Show ELF Flags info (ELF Flags is currently not used)
		# ============================================================================
		def show_elf_flags
				puts "  Flags:                             #{@elf_flags.to_h}"
		end

		# ============================================================================
		# Show size of ELF header.
		# ============================================================================
		def show_elf_h_size
			puts "  Size of this header:               #{@elf_h_size} (bytes)"
		end

		# ============================================================================
		# Show number of section headers.
		# ============================================================================
		def show_program_h_size
			puts "  Size of program headers:           #{@elf_program_h_size} (bytes)"
		end

		# ============================================================================
		# Show number of program headers.
		# ============================================================================
		def show_program_h_num
			puts "  Number of program headers:         #{@elf_program_h_num}"
		end

		# ============================================================================
		# Show size of section headers.
		# ============================================================================
		def show_section_h_size
			puts "  Size of section headers:           #{@elf_section_h_size} (bytes)"
		end

		# ============================================================================
		# Show number of section headers.
		# ============================================================================
		def show_section_h_num
			puts "  Number of section headers:         #{@elf_section_h_num}"
		end

		# ============================================================================
		# Show section name string table index.
		# ============================================================================
		def show_section_name_idx
			 puts "  Section header string table index: #{@elf_section_name_idx}"
		end

		# ============================================================================
		# get section info from section binary data.
		# ============================================================================
		def get_section_info section_header
			section_info = {}

			# index of name string in .shstrtab
			pos = 0
			section_info[:name_idx] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# section type
			section_info[:type] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# section flags
			section_info[:flags] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# address when section loaded to memory.
			section_info[:va_address] = section_header[pos, @address_size].to_i
			pos += @address_size

			# offset position of this secion in file.
			section_info[:offset] = section_header[pos, @offset_size].to_i
			pos += @offset_size

			# section size
			section_info[:size] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# Index of related section
			section_info[:related_section_idx] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# Depends on section type.
			section_info[:info] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# Allignment size.
			section_info[:addr_align] = section_header[pos, ELF_SIZE_WORD].to_i
			pos += ELF_SIZE_WORD

			# Section entry size (used when section has struct table)
			section_info[:entry_size] =  section_header[pos, ELF_SIZE_WORD].to_i
			section_info
		end

		def initialize_section_h_map

			# =======================================================
			# Get '.shstrtab' section data for take each section name.
			# =======================================================
			pos = @elf_section_h_offset + (@elf_section_name_idx * @elf_section_h_size)
			names_section_header = @bin[pos, @elf_section_h_size]
			section_info = get_section_info(names_section_header)
			names_section_pos  = section_info[:offset]
			names_section_size = section_info[:size]
			names_section = @bin[names_section_pos, names_section_size]

			# =======================================================
			# Get section info by section headers.
			# =======================================================
			@section_h_map = {}
			idx = 0
			while idx < @elf_section_h_num
				pos = @elf_section_h_offset + (idx * @elf_section_h_size)
				section_header = @bin[pos, @elf_section_h_size]
				section_info = get_section_info section_header
				section_info[:idx] = idx
				name_pos = section_info[:name_idx]
				len = names_section.length - name_pos

				if names_section.empty?
					# 空文字のセクション対応
					section_name = ""
				end

				# get section name from '.shstrtab' section
				section_name = names_section[name_pos, len].c_str
				section_info[:name] = section_name

				# section_h_map
				#  - key   : section name
				#  - value : section_info
				@section_h_map[section_name] = section_info
				idx += 1
			end

			# DEBUG
			#show_sections_info(@section_h_map.values)

			# get .strtab section
			# until set @strtab_section, can't use get_strtab_string.
			offset = @section_h_map[".strtab"][:offset]
			size = @section_h_map[".strtab"][:size]
			@strtab_section = @bin[offset, size]

			@symbol_table = get_symtab_section(@section_h_map[".symtab"], @string_map)

			# DEBUG
			#show_symbol_table(@symbol_table)

			# get relocation section info(.rela.*, .rel.*)
			@rel_sections = {}
			section_names = @section_h_map.keys
			section_names.each do |section_name|
				# search .rela.* section
				# Elf32_Rela has `r_addend`, besides Elf32_Rel.
				unless section_name.match(/.rela/).nil?
					@rel_sections[section_name] = get_rel_section(@section_h_map[section_name], @symbol_table, true)
					#show_rel_section(section_name, @rel_sections[section_name])
					next
				end

				# search .rela.* section
				unless section_name.match(/.rel/).nil?
					@rel_sections[section_name] = get_rel_section(@section_h_map[section_name], @symbol_table, false)
					#show_rel_section(section_name, @rel_sections[section_name])
					next
				end
			end

			# DEBUG
		end

		def show_rel_section section_name, rel_section
			puts "Relocation section #{section_name} at offset 0x268 contains #{rel_section.length} entries:"
			puts " Offset     Info    Type            Sym.Value  Sym. Name"
			rel_section.each do |rel_info|
				offset_str = sprintf("%08x", rel_info[:offset]).ljust(9)
				info_str = sprintf("%08x", rel_info[:info])
				type_str = rel_info[:type]
				type_str = type_str.to_s.ljust(16)
				val_str = rel_info[:symbol].to_s.ljust(15)
				name_str = rel_info[:name]
				puts "#{offset_str} #{info_str} #{type_str} #{val_str} #{name_str}"
			end
		end

		def get_strtab_string offset
			@strtab_section.c_str(offset)
		end

		# ============================================================================
		# show section info (readelf -S format)
		# ============================================================================
		def show_sections_info sections_info

			# show header line
			puts "Section Headers:"
			puts "  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al"

			# show each section info
			sections_info.each do |section_info|
				idx_str = sprintf("%2d", section_info[:idx])
				name = section_info[:name].ljust(17)
				addr_str = sprintf("%08X", section_info[:va_address])
				offset_str = sprintf("%06X", section_info[:offset])
				size_str = sprintf("%06X", section_info[:size])
				es_str = sprintf("%02X", section_info[:entry_size])

				# ======================================================
				# Section Attribute Flags(SHF bit pattern)
				# ======================================================
				flag_val = section_info[:flags]
				flg_str = ""
				flg_str += "W" if (flag_val & ELF_FLG_WRITE) != 0	# WRITE
				flg_str += "A" if (flag_val & ELF_FLG_ALLOC) != 0	# ALLOC
				flg_str += "X" if (flag_val & ELF_FLG_EXECUTE) != 0	# EXECINSTR
				flg_str += "M" if (flag_val & ELF_FLG_MERGE) != 0	# MERGE
				flg_str += "S" if (flag_val & 0x20) != 0	# STRINGS
				flg_str += "I" if (flag_val & 0x40) != 0	# INFO_LINK
				flg_str += "L" if (flag_val & 0x80) != 0	# LINK_ORDER
				flg_str += "O" if (flag_val & 0x100) != 0	# OS_NONCONFORMING
				flg_str += "G" if (flag_val & 0x200) != 0 # GROUP
				flg_str += "T" if (flag_val & 0x400) != 0	# TLS
				flg_str += "C" if (flag_val & 0x800) != 0	# COMPRESSED
				flg_str = flg_str.ljust(3)

				case section_info[:type]
				when SH_TYPE_NULL
					type_str = "NULL"
				when SH_TYPE_PROGBITS
					type_str = "PROGBITS"
				when SH_TYPE_SYMTAB
					type_str = "SYMTAB"
				when SH_TYPE_STRTAB
					type_str = "STRTAB"
				when SH_TYPE_UNDEF
					type_str = "*UNDEF*"
				when SH_TYPE_NOBITS
					type_str = "NOBITS"
				when SH_TYPE_REL
					type_str = "REL"
				else
					type_str = "UnKnown"
				end
				type_str = type_str.ljust(15)

				# TODO Link
				# link dec format.
				lk_str = sprintf("%d", section_info[:related_section_idx]).ljust(4)
				info_str = sprintf("%d", section_info[:info]).ljust(2)
				al_str = sprintf("%d", section_info[:addr_align])
				line = "  [#{idx_str}]"
				line += " #{name}"
				line += " #{type_str}"
				line += " #{addr_str}"
				line += " #{offset_str}"
				line += " #{size_str}"
				line += " #{es_str}"
				line += " #{flg_str}"
				line += " #{lk_str}"
				line += " #{info_str}"
				line += " #{al_str}"
				puts line
			end
		end

		# ============================================================================
		# show symtab secion(readelf -s format)
		# ============================================================================
		def show_symbol_table(symbol_table)
			len = symbol_table.length
			puts "Symbol table '.symtab' contains #{len} entries:"
			puts "   Num:    Value  Size Type    Bind   Vis      Ndx Name"
			symbol_table.each_with_index do |symbol_info, idx|
				num_str = "#{idx.to_s.rjust(6)}:"
				value_str = sprintf("%08x", symbol_info[:st_value])
				size_str = symbol_info[:st_size].to_s.rjust(5)

				# Type
				type = (symbol_info[:st_info] & 0x0F)
				case type
				when 0
					type_str = "NOTYPE"
				when 1
					type_str = "OBJECT"
				when 2
					type_str = "FUNC"
				when 3
					type_str = "SECTION"
				when 4
					type_str = "FILE"
				else
					type_str = "*UNDEFINED(#{type}*)"
				end
				type_str = type_str.ljust(7)

				# scope(Bind)
				scope = (symbol_info[:st_info] & 0xF0) >> 4
				case scope
				when 0
				  scope_str = "LOCAL"
				when 1
				  scope_str = "GLOBAL"
				else
				 	scope_str = "*UNDEFINED(#{scope}*)"
				end
				scope_str = scope_str.ljust(6)

				name_str = symbol_info[:name_str]

				# TODO
				shidx = symbol_info[:st_shidx]
				case shidx
				when 0
				 shidx_str = "UND"
			 	when 0xFF1F						# SHN_HIPROC
					shidx_str = "HIPROC"
				when 0xFF20						# SHN_LOOS
					shidx_str = "LOOS"
			 	when 0xFF3F						# SHN_HIOS
				 shidx_str = "HIOS"
			 	when 0xFFF1						# SHN_ABS
				 shidx_str = "ABS"
			 	when 0xFFF2						# SHN_COMMON
				 shidx_str = "CMN"
				else
					shidx_str = shidx.to_s
				end
				shidx_str = shidx_str.rjust(3)

				# TODO Vis
				vis_str = "DEFAULT".ljust(8)
				line = "#{num_str} #{value_str} #{size_str} #{type_str} #{scope_str} #{vis_str} #{shidx_str} #{name_str}"
				puts line
			end
		end

		# ============================================================================
		# get symbol_table from .symtab secion
		# ============================================================================
		def get_symtab_section symtab_section_info, string_map
			offset = symtab_section_info[:offset]
			size = symtab_section_info[:size]

			# calc size of Elf_Sym structure
			sym_h_size = ELF_SIZE_WORD + @address_size +
									 ELF_SIZE_WORD + 1 + 1 + ELF_SIZE_HALF_WORD

			# check symtab section size
			throw "symtab section size is invalid" if size % sym_h_size != 0

			symtab_section = @bin[offset, size]

			offset = 0
			left_size = size
			symbol_table = []
			loop do
				break if left_size < 1

				# =======================================================
				# Get Elf_Sym info.
				# =======================================================
				symtab_secion = {}

				# symbol name: symbol name string, offset position in .strtab section
				name_offset = symtab_section[offset, ELF_SIZE_WORD].to_i
				offset += ELF_SIZE_WORD
				symtab_secion[:name_offset] = name_offset
				symtab_secion[:name_str] = get_strtab_string(name_offset)

				# value:
				# in rel file(.o): offset position in section(.text/.bss/.data)
				# in exe file(.out): virtual address when program loaded
				st_value = symtab_section[offset, @address_size].to_i
				offset += @address_size
				symtab_secion[:st_value] = st_value

				# size: symbol size
				st_size = symtab_section[offset, ELF_SIZE_WORD].to_i
				offset += ELF_SIZE_WORD
				symtab_secion[:st_size] = st_size

				# info: symbol scope(MSB 4bit) and type(LSB 4bit)
				st_info = symtab_section[offset, 1].to_i
				offset += 1
				symtab_secion[:st_info] = st_info
				type = (st_info & 0x0F)
				symtab_secion[:type] = type

				# other: not used currently
				st_other = symtab_section[offset, 1].to_i
				offset += 1
				symtab_secion[:st_other] = st_other

				# section index: index of related section
				# if symbol is function name, section index indicates .text section.
				# Special value SHN_UNDEF, SHN_ABS, SHN_COMMON
				st_shidx = symtab_section[offset, ELF_SIZE_HALF_WORD].to_i
				offset += ELF_SIZE_HALF_WORD
				symtab_secion[:st_shidx] = st_shidx

				left_size -= sym_h_size

				# add to list
				symbol_table << symtab_secion
			end
			symbol_table
		end

		# ============================================================================
		# get .rel.text section
		# ============================================================================
		def get_rel_section rel_section_info, symbol_table, is_rela
			offset = rel_section_info[:offset]
			size = rel_section_info[:size]
			rel_section = @bin[offset, size]

			offset = 0
			left_len = size
			rel_symbol_list = []
			while 0 < left_len
				h = {}
				r_offset = rel_section[offset, @address_size].to_i
				offset += @address_size
				left_len -= @address_size

				h[:offset] = r_offset

				r_info = rel_section[offset, ELF_SIZE_WORD].to_i
				offset += ELF_SIZE_WORD
				left_len -= ELF_SIZE_WORD

				if is_rela
					bytes = rel_section[offset, ELF_SIZE_WORD]
					addr = bytes[0]
					addr += bytes[1] << 8
					addr += bytes[2] << 16
					addr += bytes[3] << 24
					r_addend = addr
				end

				offset += ELF_SIZE_WORD
				left_len -= ELF_SIZE_WORD

				r_symbol = (r_info & 0xFFFFFF00) >> 8
				r_type = r_info & 0xFF
				h[:is_rela] = is_rela
				h[:info] = r_info
				h[:symbol_idx] = r_symbol
				h[:type] = r_type
				h[:name] = symbol_table[r_symbol][:name_str]
				h[:r_addend] = r_addend
				rel_symbol_list << h
			end
			rel_symbol_list
		end

		def get_program_header
			total_h_size = @elf_program_h_num * @elf_program_h_size
			program_h_table = @bin[@elf_program_h_offset, total_h_size]

			program_h_info_list = []
			offset = 0
			while offset < total_h_size
				program_h_info = {}
				# segment type
				p_type = program_h_table[offset, ELF_SIZE_WORD]
				offset += ELF_SIZE_WORD
				program_h_info[:p_type] = p_type

				# Offset of contents
				p_offset = program_h_table[offset, @offset_size]
				offset += @offset_size
				program_h_info[:p_offset] = p_offset

				# virtual address
				p_vaaddr = program_h_table[offset, @address_size]
				offset += @address_size
				program_h_info[:p_vaaddr] = p_vaaddr

				# physical address
				p_paaddr = program_h_table[offset, @address_size]
				offset += @address_size
				program_h_info[:p_paaddr] = p_paaddr

				# segment size in file.
				p_filesz = program_h_table[offset, ELF_SIZE_WORD]
				offset += ELF_SIZE_WORD
				program_h_info[:p_filesz] = p_filesz

				# segment size in memory.
				p_memsz = program_h_table[offset, ELF_SIZE_WORD]
				offset += ELF_SIZE_WORD
				program_h_info[:p_memsz] = p_memsz

				# align size
				p_align = program_h_table[offset, ELF_SIZE_WORD]
				offset += ELF_SIZE_WORD
				program_h_info[:p_align] = p_align
				program_h_info_list << program_h_info
			end
		end

		# ============================================================================
		# Check ELF Magic Number 0x7F ELF
		# ============================================================================
		def is_elf? elf_identifer
			return false if elf_identifer[0] != 0x7F
			return false if elf_identifer[1] != 'E'.ord
			return false if elf_identifer[2] != 'L'.ord
			return false if elf_identifer[3] != 'F'.ord
			true
		end
	end
end
