all: javac

javac.tab.c javac.tab.h: javac.y
	bison -d javac.y

javac.yy.c: javalex.l javac.tab.h
	flex -v -o javac.yy.c javalex.l

javac: javac.yy.c javac.tab.c javac.tab.h
	g++ javac.tab.c javac.yy.c -o javac

clean:
	rm javac.yy.c javac.tab.c javac.tab.h javac
