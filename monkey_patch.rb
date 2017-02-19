class Array
		def c_str
			str = ""
			self.each do |c|
				break if c == 0
				str << c.chr
			end
			str
		end

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
