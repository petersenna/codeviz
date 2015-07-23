/*
 * Implementation of classname
 */
#include "classheader.h"
#include <iostream>
#include <stdlib.h>

using namespace std;

void classname::setValues(int val1, int val2) {
	setValue1(val1);
	setValue2(val2);
}

void classname::printValues() {
	cout << "Value 1: " <<privateValue1 <<endl;
	cout << "Value 2: " <<privateValue2 <<endl;
	cout << "Sum:     " <<sum <<endl;
}
