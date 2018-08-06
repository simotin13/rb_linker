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

			linked_section_map = {}

			linked_offset = 0
			elf_objects.each do |elf_object|
				# 同一のセクションのデータを配列としてまとめる
				elf_object.section_h_map.each_pair do |section_name, section_info|
					puts section_info if section_info[:name] == ".symtab"

					# セクション内の関連するシンボルを.symtblの情報から取得し、
					# シンボルテーブルに存在するシンボルはオフセットを更新する
					section_bin = elf_object.get_section_data(section_name)
					elf_object.symbol_table.map do |sym_info|
						if sym_info[:st_shidx] == section_info[:idx]
							section_info[:offset] += linked_offset
						end
					end

					# セクションサイズ分オフセットを更新
					linked_offset += section_info[:size]

					# セクション情報の初期化
 					if linked_section_map[section_name].nil?
						linked_section_map[section_name] = {section_info: section_info}
					end

					# 同一セクションのマージ
					if linked_section_map[section_name][:section_info][:name] == section_info[:name]
						# サイズ情報を更新
						linked_section_map[section_name][:section_info][:size] += section_info[:size]
						#puts section_info
					end

					# .symtab, .strtab はテーブル情報を元にバイナリを出力する
					next if section_info[:name] == ".symtab"
					next if section_info[:name] == ".strtab"

					# セクションデータ取得し結合する
					bin = elf_object.get_section_data(section_name)
					next if bin.nil?

					linked_section_map[section_name][:bin] = [] if linked_section_map[section_name][:bin].nil?
					linked_section_map[section_name][:bin].concat(bin)
				end
			end

			# 未解決のシンボルの解決を行う
			linked_section_map.each_pair do |section_name, secion_info|
				#puts secion_info
			end

			# PA → VA のマップ
			va_map = []
			va_map << {sections: ["B_1", "R_1", "B_2", "R_2", "B", "R", "SU", "SI"], address:0x00000004}
			va_map << {sections: ["PResetPRG"], address:0x0FFF00000}
			va_map << {sections: ["C_1", "C_2", "C", "C$DSEC", "C$BSEC", "C$INIT", "C$VTBL",
														"C$VECT","D_1", "D_2", "D", "P", "PIntPRG", "W_1", "W_2", "W", "L"],
														address:0x00000004}
			va_map << {sections: ["FIXEDVECT"], address:0x0FFFFFFD0}

			va_map.each do |groups|
				if groups.include?("今のセクション名")
				else
					#throw "Secion not found."
				end
			end

			# ELF header
			out_elf_header(link_f, elf_objects.first, elf_objects)

			# TODO Program Headers

			# write secion headers
			# TODO セクションヘッダの情報出力が必要
			linked_section_map.each_pair do |section_name, section|
				# link_f.write(secion[:bin].pack("C*"))	unless secion.nil?
			end

			# write secions
			linked_section_map.each_pair do |section_name, secion|
				link_f.write(secion[:bin].pack("C*"))	unless secion[:bin].nil?
			end
	  end
	end
end
