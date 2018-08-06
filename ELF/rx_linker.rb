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
	    link_f = open(filepath, "wb")
			section_size = 0

			# get symbol_name list from elf objects.
			section_objects = {}
			elf_objects.each do |elf_object|
				elf_object.symbol_table.each do |sym|
					if sym[:type] == 2 # FUNC
						#puts sym
						puts elf_object.section_h_map.keys
						#section_info[:size]
					end
				end
				
				elf_object.section_h_map.each_pair do |section_name, section_info|
					section_objects[section_name] = [] if section_objects[section_name].nil?
					section_bin = elf_object.get_section_data(section_name)
					section_objects[section_name] << {info: section_info, bin: section_bin}
				end
			end

			linked_section_map = {}
			offset = 0

			# PA → VA のマップ
			va_map = []
			va_map << {sections: ["B_1", "R_1", "B_2", "R_2", "B", "R", "SU", "SI"], address:0x00000004}
			va_map << {sections: ["PResetPRG"], address:0x0FFF00000}
			va_map << {sections: ["C_1", "C_2", "C", "C$DSEC", "C$BSEC", "C$INIT", "C$VTBL", 
														"C$VECT","D_1", "D_2", "D", "P", "PIntPRG", "W_1", "W_2", "W", "L"],
														address:0x00000004}
			va_map << {sections: ["FIXEDVECT"], address:0x0FFFFFFD0}
			
			va_map.each do |groups|
				if groups.include?(今のセクション名)
				else
					throw "Secion not found."
				end

			section_objects.each_pair do |section_name, secions|
				next if secions.empty?
				secions.each do |section|

					# TODO シンボル名に対応するセクション名はどうやって取得する？
					
				
					if linked_section_map.has_key?(section_name)
						# セクションサイズを加算
						linked_section_map[section_name][:info][:size] += section[:info][:size]
						linked_section_map[section_name][:info][:size] += section[:info][:size]
						linked_section_map[section_name][:bin].concat(section[:bin])
					else
						linked_section_map[section_name] = {info: section[:info], bin: section[:bin]}
					end
				end
				# オフセットサイズ情報を更新
				offset += linked_section_map[section_name][:info][:size]
			end

			# ELF header
			out_elf_header(link_f, elf_objects.first, elf_objects)

			# write secion headers
			# TODO セクションヘッダの情報出力が必要
			linked_section_map.each_pair do |section_name, secion|
				# link_f.write(secion[:bin].pack("C*"))	unless secion.nil?
			end

			# write secions
			linked_section_map.each_pair do |section_name, secion|
				link_f.write(secion[:bin].pack("C*"))	unless secion.nil?
			end
	  end
	end
end
