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
		bits_size=8
  	if bits_size == 32
  		sprintf("%08X", self)
		elsif bits_size == 16
  		sprintf("%04X", self)
  	else
  		sprintf("0x%02X", self)
  	end
  end
end

class ELF
	def initialize filepath
		@bin = File.binread(filepath)
		unless is_elf?
			puts "This is not ELF Format File..."
		else
			puts "Magic Number Found..."
		end


		# ELF ヘッダの解析結果出力
		read_header
	end

	# identのマジックナンバーチェック
	def is_elf?
		@ident = @bin[0, 16]
		return false if @ident[0].ord != 0x7F
		return false if @ident[1] != 'E'
		return false if @ident[2] != 'L'
		return false if @ident[3] != 'F'
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
	end

	def read_elf_class
		print "ELF Class:"
		case @ident[4].ord
		when 1
			@elf_class = "32bit"
			puts "32bit Object"
		when 2
			@elf_class = "64bit"
			puts "64bit Object"
		else
			puts "Invalid Class"
		end
	end

	def read_endian
		print "Endian:"
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
		print "ELF Version:"
		puts @ident[6].ord
	end

	def read_OS_ABI
		print "OS ABI:"
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
		puts "File Type:#{@e_type.bytes.to_i}"
	end

	def read_machie_arch
		@e_machine = @bin[18, 2]
		puts "Machine Archtecture:#{@e_machine.bytes.to_i}"
	end

	def read_file_version
		@elf_version = @bin[20, 4]
		puts "ELF File Version:#{@elf_version.bytes.to_i}"
	end

	def read_entry
		if @elf_class == "32bit"
			# 32bit
			@e_entry = @bin[24, 4]
			@pos_phoff = 28
		else
			# 64bit
			@e_entry = @bin[24, 8]
			@pos_phoff = 32
		end
	end
end

unless ARGV[0].nil?
	ELF.new ARGV[0]
else
	puts "Usage: ruby elf.rb hoge.o"
end
