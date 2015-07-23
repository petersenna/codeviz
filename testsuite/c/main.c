#include <stdio.h>
#include <stdlib.h>
#include "header.h"

#define STREAM_LENGTH 100

int main() {
	char *stream;
	int i;
	printf("Starting test program\n");

	/* Allocate stream */
	stream = malloc(STREAM_LENGTH * sizeof(char));
	if (stream == NULL) {
		printf("malloc() failed\n");
		exit(EXIT_FAILURE);
	}

	/* Fill in information */
	for (i = 0; i < STREAM_LENGTH; i++) {
		stream[i] = i;
	}

	/* Call other functions */
	processStream(stream, STREAM_LENGTH);
	manipulateStream(stream, STREAM_LENGTH);

	/* Free stream and exit */
	free(stream);
	exit(EXIT_SUCCESS);
}
