/*
 * Simple declaration for a supporting class
 */
#ifndef __CLASSHEADER_H
#define __CLASSHEADER_H

class classname {
	private:
		int privateValue1;
		int privateValue2;
		int sum;
	
		void setValue1(int val) {
			privateValue1 = val;
			sum = privateValue1 + privateValue2;
		}

		void setValue2(int val) {
			privateValue2 = val;
			sum = privateValue1 + privateValue2;
		}
			
	public:
		void setValues(int val1, int val2);
		void printValues();
};

#endif
