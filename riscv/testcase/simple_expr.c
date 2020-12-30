#include "io.h"
//This file use massive recursive expression to test: Common Expression substitution.
//For my optimized version: 	All:	1397	Load:	86	Store:	55	Jumped:	23
//For my unoptimized version:	All:	24519	Load:	12183	Store:	55	Jumped:	23
//A better result is welcomed.           ------ From JinTianxing.

int B;

int main(){
	B = -1;
	outl(0);
	outl(B);
	return 0;
}
