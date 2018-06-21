require 'elf'
require 'linker'
module ELF

	RX_SECTIONS = [
		"P",									# プログラム領域				1byte
		"C",									# const データ領域			4byte
		"C_2",								# const データ領域			2byte
		"C_1",								# const データ領域			2byte
		"D",									# 初期値ありデータ			4byte
		"D_2",								# 初期値ありデータ			2byte
		"D_1",								# 初期値ありデータ			1byte
		"SU",									# ユーザースタック領域	4byte
		"SI",									# 割り込みスタック			4byte
		"C$VECT",							# 可変ベクタテーブル(割り込みハンドラ)
		"C$DSEC",							# 初期値ありデータセクションテーブル
		"C$BSEC",							# 初期値なしデータセクション用テーブル
		"FIXEDVECT",					# 固定ベクタテーブル(割り込みハンドラ)
		"PResetPRG",					# リセットベクタ
		".symtab",						# シンボルテーブル
		".debug_info",				# デバッグ情報
		".debug_abbrev",			# ?
		".debug_line",				# ?
		".debug_pubnames",		# ?
		".debug_aranges",			# ?
		".debug_frame",				# ?
		".debug_loc",					# ?
		".strtab",						# 文字列テーブル
		".shstrtab"						# セクション文字列
	]

	class RXLinker < Linker

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

			section_map = {}
	    elf_objects.each do |elf_object|
	    	RX_SECTIONS.each do |section_name|
	    		sec = elf_object.get_section_data(section_name)
	    		next if sec.nil?
	    		if section_map.has_key?(section_name)
	    			section_map[section_name].concat(sec)
	    		else
		    		section_map[section_name] = sec
	    		end
	    	end
	    end

			# ELF header
			out_elf_header(link_f, elf_first, elf_objects)

			# write secions
			RX_SECTIONS.each do |section_name|
				sec = section_map[section_name]
				link_f.write(sec.pack("C*"))	unless sec.nil?
			end

	  end
	end
end
