/*
 * Implements a random generator for double numbers
 * 
 * Author: Konstantina Panagiotpoulou
 */


use Math;

class myRandom {

	var seed: int;
	var x: real;

	proc myRandom(seed:int){

		this.x = seed;
	}

	proc next(): real{

		x = mod((0.456*x + 0.34), 65386.0);

		return x;
	}

}
