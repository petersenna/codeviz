CXX=/usr/local/gccgraph/bin/g++
CFLAGS=-Wall -g
TESTSUITE_OBJS = main.o classname.o

%.o: %.c
	$(CXX) -c -o $@ $< $(CFLAGS)

all: testsuite
	../../bin/genfull -g cppdepn
	../../bin/gengraph -f main -k
	mv sub.graph sub.graph-default
	../../bin/gengraph -f main -k --ignore-re '.*::operator.*'
	mv sub.graph sub.graph-trimmed
	./checkgraphs.sh

testsuite: $(TESTSUITE_OBJS)
	$(CXX) -o $@ $^ $(CFLAGS)

clean:
	rm -f $(TESTSUITE_OBJS) testsuite full.graph sub.graph* *.ps *.cdepn core
