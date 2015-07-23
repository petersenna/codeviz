CC=/usr/local/gccgraph/bin/gcc
CFLAGS=-Wall -g
TESTSUITE_OBJS = main.o lib.o

%.o: %.c
	$(CC) -c -o $@ $< $(CFLAGS)

all: testsuite
	../../bin/genfull
	../../bin/gengraph -f main -k
	./checkgraphs.sh


testsuite: $(TESTSUITE_OBJS)
	$(CC) -o $@ $^ $(CFLAGS)

clean:
	rm -f $(TESTSUITE_OBJS) testsuite full.graph sub.graph* *.ps *.cdepn core
