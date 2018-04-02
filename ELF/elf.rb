module ELF
	# ============================================================================
	# ELF Identifer
	# ============================================================================
	ELF_SIZE_HALF_WORD	= 2
	ELF_SIZE_WORD				= 4
	ELF_SIZE_XWORD			= 8
	ELF_SIZE_ADDR_32		= 4
	ELF_SIZE_ADDR_64		= 8
	ELF_SIZE_OFFSET_32	= 4
	ELF_SIZE_OFFSET_64	= 8

	# ============================================================================
	# ELF Identifer
	# ============================================================================
	ELF_IDENT_SIZE	                  = 16
	ELF_IDENT_OFFSET_MAGIC_NUMBER 		= 0
	ELF_IDENT_OFFSET_CLASS						= 4
	ELF_IDENT_OFFSET_ENDIAN						= 5
	ELF_IDENT_OFFSET_FORMAT_VERSION  	= 6
	ELF_IDENT_OFFSET_OS_ABI				  	= 7
	ELF_IDENT_OFFSET_OS_ABI_VERSION 	= 8

	# ============================================================================
	# ELF CLASS
	# ============================================================================
	ELF_CLASS_ELF32 = 1
	ELF_CLASS_ELF64 = 2

	# ============================================================================
	# ELF ENDIAN
	# ============================================================================
	ELF_LITTLE_ENDIAN = 1
	ELF_BIG_ENDIAN    = 2

	# ============================================================================
	# ELF VERSION
	# ============================================================================
	ELF_CURRENT_VERSION = 1

	# ============================================================================
	# OS ABI
	# ============================================================================
	OS_ABI_UNIX = 0
	OS_ABI_LINUX = 3

	# ============================================================================
	# File version
	# ============================================================================
	EV_CURRENT = 1

	# ============================================================================
	# ELF32
	# ============================================================================
	ELF32_OFFSET_IDENTIFER   					= 0
	ELF32_OFFSET_TYPE        					= ELF32_OFFSET_IDENTIFER 						+ ELF_IDENT_SIZE
	ELF32_OFFSET_MACHINE     					= ELF32_OFFSET_TYPE 				    		+ ELF_SIZE_HALF_WORD
	ELF32_OFFSET_VERSION     					= ELF32_OFFSET_MACHINE 				 			+ ELF_SIZE_HALF_WORD
	ELF32_OFFSET_ENTRY       					= ELF32_OFFSET_VERSION 							+ ELF_SIZE_WORD
	ELF32_OFFSET_PROGRAM_HEADER	 			= ELF32_OFFSET_ENTRY 		  					+ ELF_SIZE_ADDR_32
	ELF32_OFFSET_SECTION_HEADER 			= ELF32_OFFSET_PROGRAM_HEADER 			+ ELF_SIZE_OFFSET_32
	ELF32_OFFSET_FLAGS								= ELF32_OFFSET_SECTION_HEADER				+ ELF_SIZE_OFFSET_32
	ELF32_OFFSET_ELF_HEADER_SIZE			= ELF32_OFFSET_FLAGS 								+ ELF_SIZE_WORD
	ELF32_OFFSET_PROGRAM_HEADER_SIZE  = ELF32_OFFSET_ELF_HEADER_SIZE		 	+ ELF_SIZE_HALF_WORD
	ELF32_OFFSET_PROGRAM_HEADER_NUM 	= ELF32_OFFSET_PROGRAM_HEADER_SIZE  + ELF_SIZE_HALF_WORD
	ELF32_OFFSET_SECTION_HEADER_SIZE 	= ELF32_OFFSET_PROGRAM_HEADER_NUM 	+ ELF_SIZE_HALF_WORD
	ELF32_OFFSET_SECTION_HEADER_NUM 	= ELF32_OFFSET_SECTION_HEADER_SIZE 	+ ELF_SIZE_HALF_WORD
	ELF32_OFFSET_SECTION_NAME_IDX 	  = ELF32_OFFSET_SECTION_HEADER_NUM 	+ ELF_SIZE_HALF_WORD

	# ============================================================================
	# ELF64
	# ============================================================================
	ELF64_OFFSET_IDENTIFER   					= 0
	ELF64_OFFSET_TYPE        					= ELF64_OFFSET_IDENTIFER 						+ ELF_IDENT_SIZE
	ELF64_OFFSET_MACHINE     					= ELF64_OFFSET_TYPE 				    		+ ELF_SIZE_HALF_WORD
	ELF64_OFFSET_VERSION     					= ELF64_OFFSET_MACHINE 				 			+ ELF_SIZE_HALF_WORD
	ELF64_OFFSET_ENTRY       					= ELF64_OFFSET_VERSION 							+ ELF_SIZE_WORD
	ELF64_OFFSET_PROGRAM_HEADER	 			= ELF64_OFFSET_ENTRY 		  					+ ELF_SIZE_ADDR_64
	ELF64_OFFSET_SECTION_HEADER 			= ELF64_OFFSET_PROGRAM_HEADER 			+ ELF_SIZE_OFFSET_64
	ELF64_OFFSET_FLAGS								= ELF64_OFFSET_SECTION_HEADER				+ ELF_SIZE_OFFSET_64
	ELF64_OFFSET_ELF_HEADER_SIZE			= ELF64_OFFSET_FLAGS 								+ ELF_SIZE_WORD
	ELF64_OFFSET_PROGRAM_HEADER_SIZE  = ELF64_OFFSET_ELF_HEADER_SIZE		 	+ ELF_SIZE_HALF_WORD
	ELF64_OFFSET_PROGRAM_HEADER_NUM 	= ELF64_OFFSET_PROGRAM_HEADER_SIZE  + ELF_SIZE_HALF_WORD
	ELF64_OFFSET_SECTION_HEADER_SIZE 	= ELF64_OFFSET_PROGRAM_HEADER_NUM 	+ ELF_SIZE_HALF_WORD
	ELF64_OFFSET_SECTION_HEADER_NUM 	= ELF64_OFFSET_SECTION_HEADER_SIZE 	+ ELF_SIZE_HALF_WORD
	ELF64_OFFSET_SECTION_NAME_IDX 	  = ELF64_OFFSET_SECTION_HEADER_NUM 	+ ELF_SIZE_HALF_WORD

	# ============================================================================
	# Legal values for e_type (object file type)
	# ============================================================================
	ELF_ET_NONE	= 0
	ELF_ET_REL	= 1
 	ELF_ET_EXEC = 2
	ELF_ET_DYN	= 3
	ELF_ET_CORE	= 4

end
