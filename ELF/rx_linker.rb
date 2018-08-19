require 'elf'
require 'linker'
module ELF

	# ============================================================================
	# P		プログラム領域				1byte
	#	"SU",									# ユーザースタック領域	4byte
	#	"SI",									# 割り込みスタック			4byte
	#	"FIXEDVECT",					# 固定ベクタテーブル(割り込みハンドラ)
	#	"PResetPRG",					# リセットベクタ
	#	".symtab",						# シンボルテーブル
	#	".strtab",						# 文字列テーブル
	#	".shstrtab"						# セクション文字列
	# ============================================================================
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
					secton_addrs.reverse!
					base_addr = nil
					secton_addrs.each do |secton_addr|
						tmp = secton_addr.split("/")
						base_addr = tmp[1] unless tmp[1].nil?
						name = tmp[0]
						addr = base_addr
						link_addr_maps[name] = addr
					end
				end
  		end

			puts link_addr_maps

			linked_section_map = {}

			linked_offset = 0
			symbols = []

			# ======================================================
			# 各オブジェクトファイル毎にリンク処理を行う
			# ======================================================
			rel_secions = {}
			elf_objects.each do |elf_object|
				tmp_offset = 0


				# リンクする必要がないセクションはここで削除
				elf_object.delete_section_info("$iop")
				elf_object.delete_section_info(".relaPResetPRG")
				elf_object.delete_section_info(".relaFIXEDVECT")
				symbols.concat(elf_object.symbol_table)

				# リロケーションの情報を保持しておく
				rel_secions = elf_object.rel_sections

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
				# TODO マージされたセクションの情報でシンボルテーブルを更新する
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

			linked_header.elf_section_name_idx = linked_section_map[".shstrtab"][:section_info][:idx]

			# ========================================================================
			# リロケーションの更新
			# ========================================================================
			rel_secions.each do |name, rel_section|
				rel_section.each do |rel_info|
					sym_info = symbols[rel_info[:symbol_idx]]
					target_section_name = name.slice(5..-1)
					target_section = linked_section_map[target_section_name]
					case rel_info[:type]
					when 0x01
						# 4byte のアドレスを書き換え
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info[:st_shidx]}
						ref_addr = ref_section[1][:section_info][:va_address]
						ref_addr += sym_info[:st_value]
						bytes = ref_addr.to_bin32_ary(true)
						offset = rel_info[:offset]
						target_section[:bin][offset + 0] = bytes[0]
						target_section[:bin][offset + 1] = bytes[1]
						target_section[:bin][offset + 2] = bytes[2]
						target_section[:bin][offset + 3] = bytes[3]
					when 0x0B
						rel_addr = rel_info[:r_addend] - rel_info[:offset] + 1
						target_section[:bin][rel_info[:offset]] = rel_addr
					else
						throw "Unexpected rel type, #{rel_info[:type]}"
					end
				end
			end

			# ========================================================================
			# セクションヘッダ出力オフセット計算
			# ========================================================================
			sections_size  = 0
			sections_count = 0
			linked_section_map.each_pair do |section_name, section|
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

			# ======================================================
			# write ELF Header
			# ======================================================
			cur_pos += write_elf_header(link_f, elf_objects.first)

			# ======================================================
			# write Program Headers
			# ======================================================
			prog_headers.each do |prog_header|
				cur_pos += write_prog_header(link_f, prog_header)
			end

			# ======================================================
			# write secions
			# ======================================================
			linked_section_map.each_pair do |section_name, section|
				# セクションのオフセット位置更新
				section[:section_info][:offset] = cur_pos
				cur_pos += link_f.write(section[:bin].pack("C*"))
			end

			linked_section_map.each_pair do |section_name, section|
				cur_pos += write_section_header(link_f, section[:section_info])
			end
			link_f.close
	  end
	end
end
