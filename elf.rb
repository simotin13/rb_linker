require './machine_arch_list'

class Array
		def to_i(endian=:little)
			case self.length
			when 8
				to_int64(endian)
			when 4
				to_int32(endian)
			when 2
				to_int16(endian)
			when 1
				self[0].to_i
			else
				# TODO exception...
			end
		end

		# int(64bit)
		def to_int64(endian=:little)
			if endian == :big
				(self[7].to_i << 56) +
				(self[6].to_i << 48) +
				(self[5].to_i << 40) +
				(self[4].to_i << 32) +
				(self[3].to_i << 24) +
				(self[2].to_i << 16) +
				(self[1].to_i << 8)  +
				(self[0].to_i)
			else
				# TODO スワップさせる
				self[0].to_i +
				(self[1].to_i << 8) +
				(self[2].to_i << 16) +
				(self[3].to_i << 24) +
				(self[4].to_i << 32) +
				(self[5].to_i << 40) +
				(self[6].to_i << 48) +
				(self[7].to_i << 56)
			end
		end

		# int(32bit)
		def to_int32(endian=:little)
			if endian == :big
				(self[0].to_i << 24) + (self[1].to_i << 16) + (self[2].to_i << 8) + (self[3].to_i)
			else
				self[0].to_i + (self[1].to_i << 8) + (self[2].to_i << 16) + (self[3].to_i << 24)
			end
		end

		# short(16bit)
		def to_int16(endian=:little)
			if endian == :big
				self[1].to_i + (self[0].to_i << 8)
			else
				self[0].to_i + (self[1].to_i << 8)
			end
		end
end

class Fixnum
  def to_h
		# TODO Fixnumの値によって変えるべき。。。
		if self < 0xFF
			sprintf("0x%02X", self)
  	elsif self < 0xFFFF
			sprintf("0x%04X", self)
		elsif self < 0xFFFFFFFF
			sprintf("0x%08X", self)
		elsif self < 0xFFFFFFFFFFFFFFFF
			sprintf("0x%16X", self)
  	else
			# TODO
			puts "error..."
  	end
  end
end

class ELF
	ELF_32_HEADER_SIZE = 52
	ELF_64_HEADER_SIZE = 64
	def initialize filepath
		@bin = File.binread(filepath).unpack("C*")
		unless is_elf?
			throw "This is not ELF Format File"
		end

		# ELF ヘッダの解析結果出力
		read_header
	end

	# identのマジックナンバーチェック
	def is_elf?
		@ident = @bin[0, 16]
		return false if @ident[0] != 0x7F
		return false if @ident[1] != 'E'.ord
		return false if @ident[2] != 'L'.ord
		return false if @ident[3] != 'F'.ord
		true
	end

	def read_header
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
		#read_elf_header_size
		#read_ph_size
		read_ph_num
		read_sh_num
		read_shs_idx
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
		if @elf_class == :class_32bit
			# 32bit
			@e_entry = @bin[24, @addr_size].bytes.to_i
			@pos_phoff = 28
			@pos_shoff = 32

			# e_shoff(4) + e_flags(4) + e_ehsize(2) + e_phentsize(2)
			@pos_phnum_offset = @pos_shoff + (4 + 4 + 2 + 2)

			# phnum(2) + shentsize(2)
			@pos_shnum_offset = @pos_phnum_offset + 2 + 2
			@pos_shstrndx = @pos_shnum_offset + 2
		else
			# 64bit
			@e_entry = @bin[24, @addr_size].to_i
			@pos_phoff = 32
			@pos_shoff = 40
			# e_shoff(8) + e_flags(4) + e_ehsize(2) + e_phentsize(2)
			@pos_phnum_offset = @pos_shoff + (8 + 4 + 2 + 2)

			# phnum(2) + shentsize(2)
			@pos_shnum_offset = @pos_phnum_offset + 2 + 2
			@pos_shstrndx = @pos_shnum_offset + 2
		end
		puts "entry point address		:#{@e_entry.to_h}"
	end

	def read_ph_offset
		@e_phoff = @bin[@pos_phoff, @addr_size].to_i
		puts "program header offset address	:#{@e_phoff.to_h}"
	end

	def read_sh_offset
		@e_shoff = @bin[@pos_shoff, @addr_size].to_i
		puts "section header offset address	:#{@e_shoff.to_h}"
	end

	def read_eflags
			puts "e_flags				:Not Used..."
	end

	def show_elf_header_size
		puts "elf header size	:#{ELF_32_HEADER_SIZE}"
	end

	def show_prog_header_size
		puts "program header size	:#{ELF_64_HEADER_SIZE}"
	end

	def read_ph_num
		@e_phnum = @bin[@pos_phnum_offset, 2].to_i
		puts "program header entry number	:#{@e_phnum.to_h}"
	end

	def read_sh_num
		@e_shnum = @bin[@pos_shnum_offset, 2].to_i
		puts "section header entry number	:#{@e_shnum.to_h}"
	end

	def read_shs_idx
		 @shs_idx = @bin[@pos_shstrndx, 2].to_i
		 puts "section name strings section	:#{@shs_idx.to_h}"
	end
end

unless ARGV[0].nil?
	ELF.new ARGV[0]
else
	puts "Usage: ruby elf.rb a.out"
end
