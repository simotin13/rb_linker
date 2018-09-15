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
		R_RX_DIR8S_PCREL	= 0x0B
		R_RX_ABS32				= 0x41
		R_RX_OPadd				= 0x82
		R_RX_OPsctsize		= 0x88
		R_RX_OPscttop  		= 0x8D

	  def check_elf_header objs
	    # check ELF Header of each objects
	    true
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
			puts link_options

			# 同一クラスかどうかチェック
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
			symbols = []

			# ========================================================================
			# 各オブジェクトファイル毎にリンク処理を行う
			# ========================================================================
			rel_secions = {}
			linked_sh_name_offset_map = {}
			objs.each do |elf_object|

				# ======================================================================
				# リンクする必要がないセクションはここで削除
				# ======================================================================
				elf_object.delete_section_info("$iop") if elf_object.has_section?("$iop")
				elf_object.delete_section_info(".relaPResetPRG") if elf_object.has_section?(".relaPResetPRG")
				elf_object.delete_section_info(".relaFIXEDVECT") if elf_object.has_section?(".relaFIXEDVECT")
				symbols.concat(elf_object.symbol_table)

				# リロケーションの情報を保持しておく
				rel_secions = elf_object.rel_sections

				# 同一のセクションのデータをまとめる
				sh_idx = 0
				last_section_name_size_map = {}
				cur_section_name_size_map = {}
				cur_section_idx_name_map = {}
				tmp_rela_section_info = {}
				tmp_symtab_info = {}

				elf_object.section_h_map.each_pair do |section_name, section_info|
					if linked_sh_name_offset_map[section_name].nil?
						# 最初のオブジェクトのオフセット位置
						linked_sh_name_offset_map[section_name] = 0
					end
					cur_section_name_size_map[section_name] = section_info[:size]
					cur_section_idx_name_map[sh_idx] = section_name

					# ================================================
					# relaセクション対応
					# relaセクションは退避してあとで情報を更新する
					# ================================================
					if section_name == ".relaPResetPRG"
						rela_bin = elf_object.get_section_data(section_name)
						tmp_rela_section_info[section_name] = {section_info: section_info, bin: rela_bin}
						# PResetPRGセクションのオフセット
						next
					end
					if section_name == ".relaFIXEDVECT"
						rela_bin = elf_object.get_section_data(section_name)
						tmp_rela_section_info = {section_info: section_info, bin: rela_bin}
						next
					end

					# .symtab は更新作業あるので対しして後で別途結合
					if section_name == ".symtab"
						symtab_bin = elf_object.get_section_data(section_name)
						tmp_symtab_info = {section_info: section_info, bin: symtab_bin}
						next	# .symtabは後回しにして次のセクションへ
					end

					# セクションサイズ分オフセットを更新(実体のない(SH_TYPE_NOBITS)セクションは更新不要)
					unless section_info[:type] == SH_TYPE_NOBITS
						# TODO 要確認 SH_TYPE_NOBITSを考慮しなくてよい？
					end

					# セクション情報の初期化
 					if linked_section_map[section_name].nil?
 						# 初めて登場する → リンクするセクションマップに登録
						linked_section_map[section_name] = {section_info: section_info, bin: []}
					else
						# 既に登録されているセクション → サイズ情報を更新
						linked_section_map[section_name][:section_info][:size] += section_info[:size]
					end

					# セクションの実態を取得し結合する
					secion_bin = elf_object.get_section_data(section_name)
					if secion_bin.nil?
						puts "#{section_name} is nil."
					else
						linked_section_map[section_name][:bin].concat(secion_bin)
					end

					# DEBUG セクション情報とセクション実体のサイズが一致しているか確認
					# 一致しない場合もあり得る？
					unless linked_section_map[section_name][:bin].size == linked_section_map[section_name][:section_info][:size]
						throw "Link secion size not match!"
					end

					sh_idx += 1
				end

				# ==================================================
				# リロケーションテーブル更新
				# ==================================================
				unless tmp_rela_section_info[".relaPResetPRG"].nil?
					rela_p_reset = tmp_rela_section_info[".relaPResetPRG"][:bin]
					relatab = Elf32.to_relatab(rela_p_reset)
					relatab.each do |rela|
						# PResetPRGセクションの現在のオフセットを参照
						rela.r_offset += linked_sh_name_offset_map
						# TODO r_info,r_addendは何もしなくてよいか?
					end
				end

				# ==================================================
				# シンボル情報更新
				# ==================================================
				# TODO 更新した シンボルテーブルの結合の次フェーズでの活用
				if linked_section_map[".symtab"].nil?
					# 最初のオブジェクト → 参照情報の更新不要
					linked_section_map[section_name] = tmp_symtab_info

					# 参照するセクション情報を更新
					last_section_name_size_map = cur_section_name_size_map
				else
					# 2オブジェクト目以降のシンボルテーブル →オフセット位置などの更新を行う
					sym_ary = Elf32.to_symtab(tmp_symtab_info[:bin])
					sym_ary.each do |sym|
						# シンボルテーブルが参照するセクション名を取得
						section_name = cur_section_idx_name_map[sym.st_shndx]

						# シンボル名文字列のサイズを取得しシンボルのオフセットを更新
						sym.st_name += last_section_name_size_map[".strtab"]

						# 該当するセクションのオフセット位置を取得
						# これまでに結合したセクションの合計サイズが、
						# 次に結合するセクションのオフセット位置になる
						sym.st_value += linked_sh_name_offset_map[section_name]

						# オフセット位置を更新
						linked_sh_name_offset_map[section_name] += cur_section_name_size_map[section_name]

						# 参照するセクションインデックスの更新
						# TODO ここでしない方がよい？
						sym.st_shndx = linked_section_map[section_name][:section_info][:idx]
					end

					# 参照するセクション情報を更新
					last_section_name_size_map = cur_section_name_size_map
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
			sorted_sections = linked_section_map.sort {|(key1, val1), (key2, val2)| val1[:section_info][:offset] <=> val2[:section_info][:offset] }
			linked_section_map = {}
			sorted_sections.each_with_index do |section_info, idx|
				linked_section_map[section_info[0]] = section_info[1]
				# インデックス情報を更新
				linked_section_map[section_info[0]][:section_info][:idx] = idx
			end

			# ========================================================================
			# プログラムヘッダの作成
			# ========================================================================
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
					program_h_info[:p_paddr]  = section_info[:offset]
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
