#include <iostream>
#include <stdlib.h>
#include "classheader.h"

using namespace std;

int simpleStaticFunc(int a, int b, int c) {
	/* ooh, fear the magic */
	return a + b + c;
}
int simpleStaticFunc(int a, int b) {
	return simpleStaticFunc(a, b, 0);
}

int main() {
	int a = 5, b = 10, c;
	cout <<"Starting test program\n";

	/* Call the statics */
	c = simpleStaticFunc(a, b);

	/* Work with the class */
	classname *workerClass = new classname();
	workerClass->setValues(5, 4);
	workerClass->printValues();
	
	exit(EXIT_SUCCESS);
}
