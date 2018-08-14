require 'elf'
require 'linker'
module ELF

	RX_SECTIONS = [
		"P",									# プログラム領域				1byte
		"SU",									# ユーザースタック領域	4byte
		"SI",									# 割り込みスタック			4byte
		"FIXEDVECT",					# 固定ベクタテーブル(割り込みハンドラ)
		"PResetPRG",					# リセットベクタ
		".symtab",						# シンボルテーブル
		".strtab",						# 文字列テーブル
		".shstrtab"						# セクション文字列
	]

	class RXLinker < Linker

	  def check_elf_header elf_objects
	    # check ELF Header of each objects
	    true
	  end

	  def link outfilepath, elf_objects, link_script
	    check_elf_header(elf_objects)

			link_opt = ""
			open(link_script, "r") do |linkscript_f|
				link_opt = linkscript_f.read
			end

			# リンカスクリプトからセクションの割り当てアドレスを取得する
			link_addr_maps = {}
			link_opt.each_line do |line|
				if line.include?("-start")
					secton_addrs = line.split("=")[1].split(",")
					secton_addrs.each do |secton_addr|
						tmp = secton_addr.split("/")
						link_addr_maps[tmp[0]] = tmp[1]
					end
				end
  		end

			linked_section_map = {}

			linked_offset = 0
			symbols = []
			# ======================================================
			# 各オブジェクトファイル毎にリンク処理を行う
			# ======================================================
			elf_objects.each do |elf_object|
				tmp_offset = 0

				# TODO とりあえずスキップ
				elf_object.section_h_map.delete("$iop")
				elf_object.section_h_map.delete(".relaPResetPRG")
				elf_object.section_h_map.delete(".relaFIXEDVECT")

				# 同一のセクションのデータを配列としてまとめる
				elf_object.section_h_map.each_pair do |section_name, section_info|

					# セクションサイズ分オフセットを更新
					tmp_offset += section_info[:size]

					# セクション情報の初期化
 					if linked_section_map[section_name].nil?
						linked_section_map[section_name] = {section_info: section_info, bin: []}
					else
						# 同一セクションのマージ → サイズ情報を更新
						linked_section_map[section_name][:section_info][:size] += section_info[:size]
					end

					# .symtab, .strtab はテーブル情報を元にバイナリを出力する
					# TODO 文字列、シンボル情報を更新する必要がある
					#next if section_info[:name] == ".symtab"
					#next if section_info[:name] == ".strtab"

					# セクションデータ取得し結合する
					secion_bin = elf_object.get_section_data(section_name)
					if secion_bin.nil?
						puts "#{section_name} is nil...."
						next
					end

					linked_section_map[section_name][:bin].concat(secion_bin)
				end

				# オブジェクトファイル単位で セクションサイズのオフセットを更新
				linked_offset += tmp_offset

				# シンボル情報更新
				# マージされたセクションの情報でシンボルテーブルを更新する
				elf_object.symbol_table.each do |symbol|
					section_pair = elf_object.section_h_map.find {|key,val| val[:st_shidx] == symbol[:st_shndx]}
					next if section_pair.nil?
					section_info = section_pair[1]
					# 実体がない(size=0)場合はオフセットは更新しない
					if symbol[:st_size] != 0
						symbol[:st_value] += section_info[:offset]
					end
				end

			end

			# ========================================================================
			# プログラムヘッダの作成
			# ========================================================================
			prog_headers = []
			link_addr_maps.each do |section_name, section_addr|
				section_info = linked_section_map[section_name][:section_info]
				program_h_info = {}
				# LOAD固定
				program_h_info[:p_type]   = ELF_PT_LOAD

				# セクションオフセット位置
				prog_offset =
				  ELF_SIZE_ELF32_HEADER + (ELF_SIZE_ELF32_PROG_HEADER * link_addr_maps.length)
				linked_section_map.each_pair do |name, section|
					break if section_name == name
					prog_offset += section[:bin].size
				end
				puts prog_offset
				program_h_info[:p_offset] = prog_offset

				# とりあえずROM/RAM展開はなし
				program_h_info[:p_vaddr]  = section_addr.to_i(16)
				program_h_info[:p_paddr]  = section_addr.to_i(16)

				# セクション情報をVirtualAddrssで更新
				section_info[:va_address] = section_addr.to_i(16)

				program_h_info[:p_filesz] = section_info[:size]
				program_h_info[:p_memsz]  = section_info[:size]

				# セグメントの属性を設定
				flg_val = ELF_PF_R
				flag = section_info[:flags]
				if (flag & ELF_FLG_EXECUTE) != 0
					flg_val += ELF_PF_X
				end

				program_h_info[:p_flags]  = flg_val
				program_h_info[:p_align]  = section_info[:addr_align]
				prog_headers << program_h_info
			end

			# ELF header
			linked_header = elf_objects.first
			# 実行形式として出力する
			linked_header.elf_type = ELF_ET_EXEC
			linked_header.elf_entry = 0xFFF00000
			linked_header.elf_flags = 0x00

			# プログラムヘッダ出力情報
			prog_h_offset = ELF_SIZE_ELF32_HEADER
			linked_header.elf_program_h_offset = prog_h_offset
			prog_h_size = ELF_SIZE_ELF32_PROG_HEADER
			linked_header.elf_program_h_size = ELF_SIZE_ELF32_PROG_HEADER
			linked_header.elf_program_h_num = prog_headers.length

			# TODO
			linked_header.elf_section_name_idx = 0

			# セクションヘッダ出力オフセット
			sections_size  = 0
			sections_count = 0
			linked_section_map.each_pair do |section_name, section|
				# TODO とりあえずスキップ
				next if section_name == "$iop"
				next if section_name == ".relaPResetPRG"
				next if section_name == ".relaFIXEDVECT"

				unless section[:bin].nil?
					sections_size += section[:bin].size
					sections_count += 1
				end
			end
			linked_header.elf_section_h_offset =
				ELF_SIZE_ELF32_HEADER + (prog_h_size*prog_headers.length) + sections_size
			linked_header.elf_section_h_num = sections_count

			link_f = open(outfilepath, "wb")
			cur_pos = 0

			# write ELF Header
			cur_pos += write_elf_header(link_f, elf_objects.first)

			# write Program Headers
			prog_headers.each do |prog_header|
				cur_pos += write_prog_header(link_f, prog_header)
			end
			puts "cur_pos:#{cur_pos}"

			# write secions
			linked_section_map.each_pair do |section_name, section|
				puts section_name
				# セクションのオフセット位置更新
				section[:section_info][:offset] = cur_pos
				cur_pos += link_f.write(section[:bin].pack("C*"))
			end

			# write Section Headers
			empty_section = {}
			empty_section[:name_idx] = 0
			empty_section[:type] = 0
			empty_section[:flags] = 0
			empty_section[:va_address] = 0
			empty_section[:offset] = 0
			empty_section[:size] = 0
		  empty_section[:related_section_idx] = 0
			empty_section[:info] = 0
			empty_section[:addr_align] = 0
			empty_section[:entry_size] = 0
			#write_section_header(link_f, empty_section)

			linked_section_map.each_pair do |section_name, section|
				# TODO とりあえずスキップ
				next if section_name == "$iop"
				next if section_name == ".relaPResetPRG"
				next if section_name == ".relaFIXEDVECT"

				puts "#{section_name}, #{section[:bin]}"
				cur_pos += write_section_header(link_f, section[:section_info])
			end
			link_f.close
	  end
	end
end
