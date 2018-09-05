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
		R_RX_DIR32				= 0x01
		R_RX_DIR8S_PCREL	= 0x0B
		R_RX_ABS32				= 0x41
		R_RX_OPadd				= 0x82
		R_RX_OPsctsize		= 0x88
		R_RX_OPscttop  		= 0x8D

	  def check_elf_header elf_objects
	    # check ELF Header of each objects
	    true
	  end

		# .clnkファイルによるリンク
		def link clnk_file
			link_opt = ""
			open(link_script, "r") do |linkscript_f|
				link_opt = linkscript_f.read
			end


			link_opt.each_line do |line|
				line.chomp!
				input_files = []
				output_file = ""
				if line.include?("-input")
					input_files << line.split("=")[1]
				elsif line.include?("-output")
					output_file = line.split("=")[1]
				elsif line.include?("-start")
					ary = line.split("=")[1].split(",")
					group_sections = []
					ary.each do |elm|
						tmp = elm.split("/")
						if 1 == tmp.size
							group_sections.concat(tmp)
						else
							base_addr = tmp.pop.to_i(16)
							group_sections.concat(tmp)
							link_addr_maps[base_addr] = group_sections
							link_addr_sections_num += group_sections.length

							# アドレス毎のセクション情報を初期化
							group_sections = []
						end
					end
				end
  		end
		end

	  def link outfilepath, elf_objects, clnk_file
	    check_elf_header(elf_objects)

			link_opt = ""
			open(link_script, "r") do |linkscript_f|
				link_opt = linkscript_f.read
			end

			# リンカスクリプトからセクションの割り当てアドレスを取得する
			link_addr_maps = {}
			link_addr_sections_num = 0
			link_opt.each_line do |line|
				line.chomp!
				if line.include?("-start")
					ary = line.split("=")[1].split(",")
					group_sections = []
					ary.each do |elm|
						tmp = elm.split("/")
						if 1 == tmp.size
							group_sections.concat(tmp)
						else
							base_addr = tmp.pop.to_i(16)
							group_sections.concat(tmp)
							link_addr_maps[base_addr] = group_sections
							link_addr_sections_num += group_sections.length

							# アドレス毎のセクション情報を初期化
							group_sections = []
						end
					end
				end
  		end

			linked_section_map = {}
			linked_offset = 0
			symbols = []

			# ========================================================================
			# 各オブジェクトファイル毎にリンク処理を行う
			# ========================================================================
			rel_secions = {}
			elf_objects.each do |elf_object|
				tmp_offset = 0

				# ======================================================================
				# リンクする必要がないセクションはここで削除
				# ======================================================================
				elf_object.delete_section_info("$iop")
				elf_object.delete_section_info(".relaPResetPRG")
				elf_object.delete_section_info(".relaFIXEDVECT")
				symbols.concat(elf_object.symbol_table)

				# リロケーションの情報を保持しておく
				rel_secions = elf_object.rel_sections

				# 同一のセクションのデータを配列としてまとめる
				elf_object.section_h_map.each_pair do |section_name, section_info|

					# セクションサイズ分オフセットを更新
					unless section_info[:type] == SH_TYPE_NOBITS
						tmp_offset += section_info[:size]
					end

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
						puts "#{section_name} is nil."
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
			# セクションのアドレス・サイズ情報を更新
			# ========================================================================
			link_addr_maps.each do |section_addr, section_names|
				va_addr_end = section_addr
				section_names.each do |section_name|
					linked_section_map[section_name][:section_info][:va_address] = va_addr_end
					va_addr_end += linked_section_map[section_name][:section_info][:size]
				end
			end

			# ========================================================================
			# セクションのソート
			# オフセットを基準にセクション情報をソートする
			# ソートする際には、各セクションを参照する値も同時に更新する必要がある
			# ========================================================================
			sorted_sections = linked_section_map.sort {|(key1, val1), (key2, val2)| val1[:section_info][:offset] <=> val2[:section_info][:offset] }
			linked_section_map = {}
			sorted_sections.each_with_index do |section_info, idx|
				linked_section_map[section_info[0]] = section_info[1]
				# インデックス情報を更新
				linked_section_map[section_info[0]][:section_info][:idx] = idx
			end
			linked_section_map[".shstrtab"][:section_info][:idx]

			# ========================================================================
			# プログラムヘッダの作成
			# ========================================================================
			prog_headers = []
			link_addr_maps.each do |section_addr, section_names|
				section_names.each do |section_name|
					section_info = linked_section_map[section_name][:section_info]
					program_h_info = {}
					# LOAD固定
					program_h_info[:p_type]   = ELF_PT_LOAD

					# セクションオフセット位置
					prog_offset = 0
					prog_offset = ELF_SIZE_ELF32_HEADER + (ELF_SIZE_ELF32_PROG_HEADER * link_addr_sections_num)

					# セクションのオフセット位置を計算
					linked_section_map.each_pair do |name, section|
						break if section_name == name
						prog_offset += section[:bin].size
					end

					if section_info[:type] == SH_TYPE_NOBITS
						prog_offset = 0
					end
					program_h_info[:p_offset] = prog_offset

					# とりあえずROM/RAM展開はなし
					program_h_info[:p_vaddr]  = section_info[:va_address]
					program_h_info[:p_paddr]  = section_info[:offset]

					# TODO 計算済み?
					# セクション情報をVirtualAddrssで更新
					#section_info[:va_address] = section_addr

					program_h_info[:p_filesz] = section_info[:size]
					program_h_info[:p_memsz]  = section_info[:size]

					# セグメントの属性を設定
					flg_val = ELF_PF_R
					flag = section_info[:flags]
					if (flag & ELF_FLG_EXECUTE) != 0
						flg_val += ELF_PF_X
					end
					if (flag & ELF_FLG_WRITE) != 0
						flg_val += ELF_PF_W
					end

					program_h_info[:p_flags]  = flg_val
					program_h_info[:p_align]  = section_info[:addr_align]
					prog_headers << program_h_info
				end
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
			rel_calc_stack = []
			rel_secions.each do |name, rel_section|
				rel_section.each do |rel_info|
					sym_info = symbols[rel_info[:symbol_idx]]
					target_section_name = name.slice(5..-1)
					target_section = linked_section_map[target_section_name]

					case rel_info[:type]
					when R_RX_DIR32
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
					when R_RX_ABS32
						val = rel_calc_stack.pop
						bytes = val.to_bin32_ary(true)
						offset = rel_info[:offset]
						target_section[:bin][offset + 0] = bytes[0]
						target_section[:bin][offset + 1] = bytes[1]
						target_section[:bin][offset + 2] = bytes[2]
						target_section[:bin][offset + 3] = bytes[3]
					when R_RX_OPscttop
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info[:st_shidx]}
						rel_calc_stack << ref_section[1][:section_info][:va_address]
					when R_RX_OPsctsize
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info[:st_shidx]}
						rel_calc_stack << ref_section[1][:section_info][:size]
					when R_RX_OPadd
						arg1 = rel_calc_stack.pop
						arg2 = rel_calc_stack.pop
						val = arg1 + arg2
						rel_calc_stack << val
					when R_RX_DIR8S_PCREL
						rel_addr = rel_info[:r_addend] - rel_info[:offset] + 1
						target_section[:bin][rel_info[:offset]] = rel_addr
					else
						throw "Unexpected rel type, #{rel_info[:type].to_h}"
					end
				end
			end

			# ========================================================================
			# セクションヘッダ出力オフセット計算
			# ========================================================================
			sections_size  = 0
			sections_count = 0
			linked_section_map.each_pair do |section_name, section|
				if section[:section_info][:type] == SH_TYPE_NOBITS
					# 実体のないセクションはセクションヘッダのみ書き込みを行う
					sections_count += 1
					next
				end
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
				# 実体のないセクションは書き込み不要
				next if section[:section_info][:type] == SH_TYPE_NOBITS

				# セクションのオフセット位置更新
				section[:section_info][:offset] = cur_pos
				cur_pos += link_f.write(section[:bin].pack("C*"))
			end

			# ======================================================
			# write section headers
			# ======================================================
			linked_section_map.each_pair do |section_name, section|
				cur_pos += write_section_header(link_f, section[:section_info])
			end
			link_f.close
	  end
	end
end
