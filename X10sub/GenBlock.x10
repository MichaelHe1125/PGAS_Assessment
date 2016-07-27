/*
 * Implements the caller class which generates the universe 
 * and calls main() function
 * Author: Konstantina Panagiotopoulou 2013
 */

import UniverseC;
import Body;
import myRandom;

import x10.util.Timer;
import x10.io.Printer;
import x10.io.Console;
import x10.util.*;

class GenBlock{
		

	    static val bodies: Int = 4;	//total number of bodies in the universe	
		
		static val x: double = 3.5;	//dimension x of the universe
		static val y: double = 4.2;	//dimension y of the universe

		static val dt:double = 0.1;	//interval of iterations

		static val numIterations: Int = 120;	//total number of iterations

		
		static val verbose :boolean = true;	//printing control
		
		static val B:Region(1) = 0..bodies;
		
	public def run(bodies: Int, verbose:boolean){
		
		//calculates the chunk size for each place
		val chunk: Int = (bodies / Place.MAX_PLACES) + ((bodies % Place.MAX_PLACES > 0) ? 1 : 0);	
		//instantiates a UniverceC object
		val uni = new UniverseC(x, y, bodies, chunk); 
		
		//starts the timer
		val fill = new Timer();
		val startfill: long = fill.milliTime();
		
		//calls fillUniverse function
		uni.fillUniverse(chunk, bodies);
		
		//stops the timer
		val stopfill: long = fill.milliTime();
		
		//prints the initial positions of the bodies in teh universe
		if (verbose){
			Console.OUT.println("==== Initial positions ====");
			uni.printBodies();//bo);
		}
		
		
		var e: double = 0.0;
		var d : Double = 0.0;
		//starts a new timer
		val t = new Timer();
		
		
		val start: long = t.milliTime();

		//calls the advance function numIterations times and sums up its result in d (total energy)
		for (var i: Int = 1; i <= numIterations; i++) {
				
			d += uni.Advance(dt);
		}
		
		//stops timer
		val stop: long = t.milliTime();

		//prints final positions of the bodies in the universe
		if (verbose){
			
			Console.OUT.println("==== Final positions ====");
			uni.printBodies();
		}
		//calculates elapsed time
		val total:long = stop-start;
		val filltotal:long = stopfill - startfill;
		
		//prints elapsed time and total energy
		Console.OUT.println("Total energy : "+d);
		Console.OUT.println("");
		Console.OUT.println("Time elapsed: "+((total as double)/1e9));
		Console.OUT.println("Time for initialisation: "+((filltotal as double)/1e9));
		
	}

	//the main() function of teh program
	public static def main(args: Array[String](1)) 
	{
		val nb = Int.parse(args(0));
		val ver = Int.parse(args(1));
		var v: boolean;
		if (ver==0){ v = false;}
		else{v = true;}

		//instantiates a new GenBlock object and calls run function
		new GenBlock().run(nb, v);
		
	}
}

