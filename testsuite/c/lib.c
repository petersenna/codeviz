#include <stdio.h>
#include "header.h"

/* This is stupid obviously, am looking for a type of graph */
int _processStream(char *byteStream, int length, int depth) {
	printf("At depth %d\n", depth);
	if (length != depth) {
		byteStream[depth]++;
		_processStream(byteStream, length, depth+1);
	}
	return 0;
}

int processStream(char *byteStream, int length) {
	return _processStream(byteStream, length, 0);
}

int manipulateStream(char *byteStream, int length) {
	printf("Called manipulateStream\n");
	return 1;
}

