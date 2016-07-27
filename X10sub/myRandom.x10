/*
 * Implements a random generator of double numbers
 * Author: Konstantina Panagiotopoulou 2013
 */

import x10.util.Random;
import x10.io.Printer;


public class myRandom {

	var seed: Int;
	var x: Double;

	def this(seed:Int){

		this.x = seed;
	}

	public def next(): Double{

		x = (0.456*x + 0.34) % 65386;

		return x;
	}

}	//class myRandom 

	
