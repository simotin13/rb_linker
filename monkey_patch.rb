class Integer
  def to_h(prefix=true, capital=true)
		prefix_str = ""
		prefix_str = "0x" if prefix
		format_str = ""
		if capital
			format_str += "X"
		else
			format_str += "x"
		end

		if self < 0xFF
			sprintf("#{prefix_str}%02#{format_str}", self)
  	elsif self < 0xFFFF
			sprintf("#{prefix_str}%04#{format_str}", self)
		elsif self < 0xFFFFFFFF
			sprintf("#{prefix_str}%08#{format_str}", self)
		elsif self < 0xFFFFFFFFFFFFFFFF
			sprintf("#{prefix_str}%16#{format_str}", self)
  	else
			# TODO
			puts "error..."
  	end
  end
end

class Array
	def c_str(offset = 0)
		str = ""
		while offset < self.length
			break if self[offset] == 0
			str << self[offset].chr
			offset += 1
		end
		str
	end

	def hex_dump(prefix=true, capital=true)
		dump_str = ""
		self.each_with_index do |val, i|
			dump_str += "#{val.to_h(prefix, capital)} "
			dump_str += "\n" if i % 16 == 15
		end
		dump_str
	end

	def to_i(is_little=true)
		case self.length
		when 8
			to_int64(is_little)
		when 4
			to_int32(is_little)
		when 2
			to_int16(is_little)
		when 1
			self[0].to_i
		else
			# TODO exception...
		end
	end

	# int(64bit)
	def to_int64(is_little=true)
		if is_little
			self[0].to_i +
			(self[1].to_i << 8) +
			(self[2].to_i << 16) +
			(self[3].to_i << 24) +
			(self[4].to_i << 32) +
			(self[5].to_i << 40) +
			(self[6].to_i << 48) +
			(self[7].to_i << 56)
		else
			(self[7].to_i << 56) +
			(self[6].to_i << 48) +
			(self[5].to_i << 40) +
			(self[4].to_i << 32) +
			(self[3].to_i << 24) +
			(self[2].to_i << 16) +
			(self[1].to_i << 8)  +
			(self[0].to_i)
		end
	end

	# int(32bit)
	def to_int32(is_little=true)
		if is_little
			self[0].to_i + (self[1].to_i << 8) + (self[2].to_i << 16) + (self[3].to_i << 24)
		else
			(self[0].to_i << 24) + (self[1].to_i << 16) + (self[2].to_i << 8) + (self[3].to_i)
		end
	end

	# short(16bit)
	def to_int16(is_little=true)
		if is_little
			self[0].to_i + (self[1].to_i << 8)
		else
			self[1].to_i + (self[0].to_i << 8)
		end
	end
end
