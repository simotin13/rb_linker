CC=gcc

SRCS	=		\
	main.c		\
	func.c		\
	ext_func.c

OBJS	=		\
	main.o		\
	func.o		\
	ext_func.o

TARGET=test_exe.out

all:
	${CC} -c ${SRCS}
	${CC} -o ${TARGET} ${OBJS}

clean:
	rm *.o ${TARGET}
