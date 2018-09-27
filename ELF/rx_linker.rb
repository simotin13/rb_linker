require 'elf'
require 'linker'
require 'elf32'
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
		R_RX_DIR24S_PCREL = 0x09
		R_RX_DIR8S_PCREL	= 0x0B
		R_RX_ABS32				= 0x41
		R_RX_OPadd				= 0x82
		R_RX_OPsctsize		= 0x88
		R_RX_OPscttop  		= 0x8D

	  def check_elf_header objs
	    # TODO check ELF Header of each objects
	    true
	  end

		# .rela セクションの情報を更新する
		def update_rela_sections section_name, rela_section, section_name_offset_map
			# 現在のオブジェクトファイルの.relaPResetPRG を取得しクラスに変換
			bin = rela_section[section_name][:bin]
			relatab = Elf32.to_relatab(bin)

			# 各リロケーション情報の以下の内容を更新する
			#  r_offset(再配置先オフセット) 再配置により値を埋め込むセクションでのオフセット
			#  synbol idx(higher 24 bit of r_info) relocation symbol index of .symtab
			rel_bin = []
			relatab.each do |rela|
				# PResetPRGセクションの現在のオフセットを参照
				# .rela を切り取り
				target_section_name = section_name.slice(5..-1)
				target_cur_offset = section_name_offset_map[target_section_name]
				rela.r_offset += target_cur_offset
				rel_bin.concat(rela.to_bin)
			end
			rel_bin
		end

		# ==========================================================================
		# make program header
		# ==========================================================================
		def make_program_header link_options, linked_section_map
			prog_headers = []
			link_options[:addr_map].each do |section_addr, section_names|
				section_names.each do |section_name|
					section_info = linked_section_map[section_name][:section_info]
					program_h_info = {}
					# LOAD固定
					program_h_info[:p_type]   = ELF_PT_LOAD

					# セクションオフセット位置
					prog_offset = 0
					prog_offset = ELF_SIZE_ELF32_HEADER + (ELF_SIZE_ELF32_PROG_HEADER * link_options[:addr_sections_num])

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
					program_h_info[:p_paddr]  = section_info[:va_address]
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
			prog_headers
		end

		# ==========================================================================
		# relocate rela sections
		# ==========================================================================
		def relocate_rela_sections rela_section_names, linked_section_map
			rel_secions = {}
			rela_section_names.each do |rela_section_name|
				rel_secions[rela_section_name] = Elf32.to_relatab(linked_section_map[rela_section_name][:bin])
			end

			symtab = Elf32.to_symtab(linked_section_map[".symtab"][:bin])
			rel_calc_stack = []
			rel_secions.each do |name, reltab|
				reltab.each do |rel_info|
					sym_info = symtab[rel_info.symbol_idx]
					target_section_name = name.slice(5..-1)
					target_section = linked_section_map[target_section_name]
					case rel_info.type
					when R_RX_DIR32
						# 4byte のアドレスを書き換え
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info.st_shndx}
						ref_addr = ref_section[1][:section_info][:va_address]
						ref_addr += sym_info.st_value
						bytes = ref_addr.to_bin32_ary(true)
						target_section[:bin][rel_info.r_offset + 0] = bytes[0]
						target_section[:bin][rel_info.r_offset + 1] = bytes[1]
						target_section[:bin][rel_info.r_offset + 2] = bytes[2]
						target_section[:bin][rel_info.r_offset + 3] = bytes[3]
					when R_RX_ABS32
						val = rel_calc_stack.pop
						bytes = val.to_bin32_ary(true)
						target_section[:bin][rel_info.r_offset + 0] = bytes[0]
						target_section[:bin][rel_info.r_offset + 1] = bytes[1]
						target_section[:bin][rel_info.r_offset + 2] = bytes[2]
						target_section[:bin][rel_info.r_offset + 3] = bytes[3]
					when R_RX_OPscttop
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info.st_shndx}
						rel_calc_stack << ref_section[1][:section_info][:va_address]
					when R_RX_OPsctsize
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info.st_shndx}
						rel_calc_stack << ref_section[1][:section_info][:size]
					when R_RX_OPadd
						arg1 = rel_calc_stack.pop
						arg2 = rel_calc_stack.pop
						val = arg1 + arg2
						rel_calc_stack << val
					when R_RX_DIR8S_PCREL
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info.st_shndx}
						ref_section_name = ref_section[0]
						target_addr = target_section[:section_info][:va_address] + rel_info.r_offset
						ref_addr = ref_section[1][:section_info][:va_address] + sym_info.st_value

						# plus 1byte for opecode
						rel_addr = rel_info.r_addend + ref_addr - target_addr + 1
						bytes = rel_addr.to_bin32_ary(true)
						target_section[:bin][rel_info.r_offset + 0] = rel_addr
					when R_RX_DIR24S_PCREL
						ref_section = linked_section_map.find{|key,val| val[:section_info][:idx] == sym_info.st_shndx}
						ref_section_name = ref_section[0]
						target_addr = target_section[:section_info][:va_address] + rel_info.r_offset
						ref_addr = ref_section[1][:section_info][:va_address] + sym_info.st_value

						# plus 1byte for opecode
						rel_addr = rel_info.r_addend + ref_addr - target_addr + 1

						bytes = rel_addr.to_bin32_ary(true)
						target_section[:bin][rel_info.r_offset + 0] = bytes[0]
						target_section[:bin][rel_info.r_offset + 1] = bytes[1]
						target_section[:bin][rel_info.r_offset + 2] = bytes[2]
					else
						throw "Unexpected rel type, #{rel_info.type.to_h}"
					end
				end
			end
		end

	  # .clnkファイルの内容を取得する
	  def get_options clnk_file

	  	link_options = {}
			input_files = []
			output_file = ""
			link_addr_map = {}
			link_addr_sections_num = 0
			base_dir = File.dirname(clnk_file)

			open(clnk_file, "r") do |f_script|
				lines =f_script.read
				lines.each_line do |line|
					line.chomp!
					if line.include?("-input")
						filepath = "#{base_dir}/#{File.basename(line.split("=")[1])}"
						# .mot への変換を無視するため
						input_files << filepath if File.extname(filepath) == ".obj"
					elsif line.include?("-output")
						filepath = "#{base_dir}/#{File.basename(line.split("=")[1])}"
						# .mot への変換を無視するため
						output_file = filepath if File.extname(filepath) == ".abs"
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
								link_addr_map[base_addr] = group_sections
								link_addr_sections_num += group_sections.length

								# アドレス毎のセクション情報を初期化
								group_sections = []
							end
						end
					end
	  		end
			end
			link_options[:input] = input_files
			link_options[:output] = output_file
			link_options[:addr_map] = link_addr_map
			link_options[:addr_sections_num] = link_addr_sections_num
			link_options
	  end

		# ==========================================================================
		# .clnkファイルによるリンク
		# ==========================================================================
		def link clnk_file

			# ====================================================
			# 各ファイルの内容を読出し
			# ====================================================
			objs = []
			elf_class = nil
			link_options = get_options(clnk_file)

			# 同一クラスかどうかチェック
			puts "Input object files #{link_options[:input]}"
			link_options[:input].each do |input_file|
			  elf_obj = ELF::ElfObject.new(input_file)
			  if elf_class.nil?
			    elf_class = elf_obj.elf_class
			  else
			    throw "Different Elf Class found!" if elf_class != elf_obj.elf_class
			  end
			  objs << elf_obj
			end

	    check_elf_header(objs)

			linked_section_map = {}
			rela_section_names = [".relaPResetPRG", ".relaFIXEDVECT"]

			# ========================================================================
			# 各オブジェクトファイル毎にリンク処理を行う
			# ========================================================================
			linked_sh_name_offset_map = {}
			objs.each do |elf_object|

				#sh_idx = 0
				cur_section_name_size_map = {}
				cur_section_idx_name_map = {}
				tmp_rela_section_info = {}
				tmp_symtab_info = {}

				# ======================================================================
				# オブジェクト内の各セクション毎に結合を行う
				# ======================================================================
				elf_object.section_h_map.each_with_index  do |(section_name, section_info), sh_idx|
					if linked_sh_name_offset_map[section_name].nil?
						# 最初のオブジェクトのオフセット位置
						linked_sh_name_offset_map[section_name] = 0
					end
					cur_section_name_size_map[section_name] = section_info[:size]
					cur_section_idx_name_map[sh_idx] = section_name

					# 関連するセクションへのインデックスを更新
					related_section_name = elf_object.related_section_name(section_name)
					unless linked_section_map[related_section_name].nil?
						section_info[:related_section_idx] = linked_section_map[related_section_name][:section_info][:idx]
					end

					# ================================================
					# relaセクション対応
					# relaセクションは退避してあとで情報を更新する
					# ================================================
					if rela_section_names.include?(section_name)
						rela_bin = elf_object.get_section_data(section_name)
						tmp_rela_section_info[section_name] = {section_info: section_info, bin: rela_bin}
						next
					end

					# .symtab は内容の更新が必要→退避してから別途結合する
					if section_name == ".symtab"
						symtab_bin = elf_object.get_section_data(section_name)
						tmp_symtab_info = {section_info: section_info, bin: symtab_bin}
						next	# .symtabは後回しにして次のセクションへ
					end

					# セクション情報の初期化
 					if linked_section_map[section_name].nil?
 						# 初めて登場する → リンクするセクションマップに登録
						linked_section_map[section_name] = {section_info: section_info, bin: []}
					else
						# 既に登録されているセクション → サイズ情報を更新
						linked_section_map[section_name][:section_info][:size] += section_info[:size]
					end

					# セクションサイズ分オフセットを更新(実体のない(SH_TYPE_NOBITS)セクションは更新不要)
					if section_info[:type] == SH_TYPE_NOBITS
						# TODO 要確認 SH_TYPE_NOBITSを考慮しなくてよい？
						next
					end

					# セクションの実体を取得し結合する
					secion_bin = elf_object.get_section_data(section_name)
					if secion_bin.nil?
						puts "#{section_name} is nil."
					else
						linked_section_map[section_name][:bin].concat(secion_bin)
					end

					# セクション情報とセクション実体のサイズが一致しているか確認
					unless linked_section_map[section_name][:bin].size == linked_section_map[section_name][:section_info][:size]
						puts "section_name:#{section_name}, bin:#{linked_section_map[section_name][:bin].size.to_h}, info:#{linked_section_map[section_name][:section_info][:size].to_h}"
						throw "Link secion size not match!"
					end
				end

				# TODO 更新した シンボルテーブルの結合の次フェーズでの活用
				if linked_section_map[".symtab"].nil?
					# 最初のオブジェクト → 参照情報の更新不要
					linked_section_map[".symtab"] = tmp_symtab_info
				else
					# 2オブジェクト目以降のシンボルテーブル →オフセット位置などの更新を行う
					sym_ary = Elf32.to_symtab(tmp_symtab_info[:bin])
					sym_ary.each do |sym|
						# .strtabは結合ずみ
						sym.st_name += linked_sh_name_offset_map[".strtab"]
						# シンボル名を文字列として取得
						sym_name = linked_section_map[".strtab"][:bin].c_str(sym.st_name)
						if sym.has_ref_section?
							ref_section_name = cur_section_idx_name_map[sym.st_shndx]
							sym.st_value += linked_sh_name_offset_map[ref_section_name]
						end

						# 重複するシンボルの探索
						has_same_symbol = false
						pre_symtab = Elf32.to_symtab(linked_section_map[".symtab"][:bin])
						pre_symtab.each do |pre_sym|
							pre_sym_name = linked_section_map[".strtab"][:bin].c_str(pre_sym.st_name)
							if sym_name == pre_sym_name
								# 既に同一シンボル名のエントリが存在する場合は上書きする
								has_same_symbol = true
								pre_sym.st_value = sym.st_value
								pre_sym.st_size = sym.st_size
								pre_sym.st_info = sym.st_info
								pre_sym.st_other = sym.st_other
								pre_sym.st_shndx = sym.st_shndx

								# 更新結果を書き戻し
								linked_section_map[".symtab"][:bin] = Elf32.symtab_to_bin(pre_symtab)
								break
							end
						end

						# 重複シンボルを更新済みの場合は次へ...
						if has_same_symbol
							next
						end

						if sym.type == STT_NOTYPE
							# 空のシンボル対応
							puts "Symbol type is STT_NOTYPE"
							next
						end

						if sym.has_ref_section?
							# 参照するセクションのインデックスが保持されている
							ref_section_name = cur_section_idx_name_map[sym.st_shndx]
							# 現在のセクションインデックスで更新
							sym.st_shndx = linked_section_map[ref_section_name][:section_info][:idx]
						else
							next
						end

						# シンボル情報をテーブルに追加
						linked_section_map[".symtab"][:bin].concat(sym.to_bin)
					end
				end

				# ==================================================
				# リロケーションテーブル更新
				# ==================================================
				rela_section_names.each do |rela_secion_name|
					unless tmp_rela_section_info[rela_secion_name].nil?
						rela_section = update_rela_sections(rela_secion_name, tmp_rela_section_info, linked_sh_name_offset_map)
						# セクション名のインデックスを更新
						tmp_rela_section_info[rela_secion_name][:section_info][:name_idx] += linked_sh_name_offset_map[".shstrtab"]
						if linked_section_map[rela_secion_name].nil?
							# relaPResetPRGが最初に出てきた場合
							linked_section_map[rela_secion_name] = {section_info: tmp_rela_section_info[rela_secion_name][:section_info], bin: []}
						end
						# リロケーション情報を更新
						linked_section_map[rela_secion_name][:bin].concat(rela_section)
					end
				end

				# =====================================================
				# オフセット位置を更新
				# =====================================================
				cur_section_name_size_map.each do |section_name, offset|
					linked_sh_name_offset_map[section_name] += offset
				end
			end

			# ========================================================================
			# セクションのアドレス・サイズ情報を更新
			# ========================================================================
			link_options[:addr_map].each do |section_addr, section_names|
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
			# セクションのインデックス-セクション名のマップを作る
			old_section_idx_name_map = {}
			linked_section_map.each do |section_name, section|
				idx = section[:section_info][:idx]
				old_section_idx_name_map[idx] = section_name
			end

			symtab = Elf32.to_symtab(linked_section_map[".symtab"][:bin])
			sorted_sections = linked_section_map.sort {|(key1, val1), (key2, val2)| val1[:section_info][:offset] <=> val2[:section_info][:offset] }
			linked_section_map = {}
			sorted_sections.each_with_index do |section, idx|
				section_name = section[0]
				section_info = section[1]
				linked_section_map[section_name] = section_info
				# インデックス情報を更新
				linked_section_map[section_name][:section_info][:idx] = idx
			end

			# ソート後のセクションインデックスで関連するセクションインデックスを更新する
			linked_section_map.each do |section_name, section|
				related_section_idx = section[:section_info][:related_section_idx]
				related_section_name = old_section_idx_name_map[related_section_idx]
				section[:section_info][:related_section_idx] = linked_section_map[related_section_name][:section_info][:idx]
			end

			# ======================================================================
			# リンクする必要がないセクションはここで削除
			# ======================================================================
			iop_idx = linked_section_map["$iop"][:section_info][:idx]
			linked_section_map.delete("$iop")
			linked_section_map.each do |section_name, section|
				idx = section[:section_info][:idx]
				related_idx = 0
				unless section[:section_info][:related_section_idx].nil?
					related_idx = section[:section_info][:related_section_idx]
				end

				if iop_idx <= idx
					section[:section_info][:idx] -= 1
				end
				if iop_idx <= related_idx
					section[:section_info][:related_section_idx] -= 1
				end
			end

			# ソート結果に合わせてシンボルテーブルの参照インデックスを更新
			symtab.each do |sym|
				if sym.has_ref_section?
					ref_section_name = old_section_idx_name_map[sym.st_shndx]
					new_idx = linked_section_map[ref_section_name][:section_info][:idx]
					sym.st_shndx = new_idx
				end
			end
			# シンボルテーブル更新結果を上書き
			linked_section_map[".symtab"][:bin] = Elf32.symtab_to_bin(symtab)

			# relocate rela section
			relocate_rela_sections(rela_section_names, linked_section_map)

			# リンク不要なセクションをここで削除
			# 多分インデックスはここ以降ではされないはず
			rela_section_names.each do |rela_section_name|
				linked_section_map.delete(rela_section_name)
			end

			# ========================================================================
			# make program header
			# ========================================================================
			prog_headers = make_program_header(link_options, linked_section_map)

			# ELF header
			linked_header = objs.first
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

			# calc section header offset size
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

			link_f = open(link_options[:output], "wb")
			cur_pos = 0

			# ======================================================
			# write ELF Header
			# ======================================================
			cur_pos += write_elf_header(link_f, objs.first)

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
