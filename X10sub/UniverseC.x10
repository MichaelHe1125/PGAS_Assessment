/*
 * Implements teh universe object where all bodies interact.
 * This class handles the communication between places and performs the calculations
 * Author: Konstantina Panagiotopoulou 2013
 */


import x10.util.Random;
import Body;
import x10.io.Printer;
import x10.io.Console;
import x10.lang.Math;
import x10.array.DistArray;
import x10.util.*;
import x10.compiler.Uncounted;
import x10.util.Team;
import x10.lang.Reducible.*;

import x10.io.File;
import x10.io.FileReader;

public class UniverseC {

	public var dimx: double;	//dimension x of the universe
	public var dimy: double;	//dimension y of the universe
	public var numBodies: Int;	//total number of bodies in the universe
	
	
	public var e: double;		//energy

	public val dt:double =3;	//interval of iterations
	
	public var chunk:Int;		//chunk size

	
	//distributed array of bodies
    private val bodies : DistArray[Rail[Body]](1);
    //distributed array of arrays of bodies
   	private val otherBodies : DistArray[Rail[Rail[Body]]](1);
   	
   	//constructor	
   	public def this( dimx: double, dimy: double, numBodies: Int , chunk: Int){ 

		this.dimx = dimx;
		this.dimy = dimy;
		this.chunk = chunk;
		/* The bodies array is distributed over the available places
		 * using the Unique distribution, which assigns each element to a different place and 
		 * every elements to one place
		 */
		this.bodies = DistArray.make[Rail[Body]](Dist.makeUnique()); 
		/* The otherBodies array is distributed over teh available places, again
		 * using the Unique distribution and contains non distributed arrays 
		 * of size Place.MAX_PLACES
		 */
		this.otherBodies = DistArray.make[Rail[Rail[Body]]](Dist.makeUnique(), (p : Point) => new Rail[Rail[Body]](Place.MAX_PLACES));
		
    }

	/*nitialises the distributed bodies array
	 * using the non-distributed array init
	 */
	public def fillUniverse(chunkSize: Int, numBodies: Int){ 
		
	
		val init = new Rail[Body](numBodies);
		
		var z:Int  = 2001;
		//generates random values for the elements (bodies) of the array init
		for (i in 0..(numBodies-1)){
				
				
				val r = new myRandom(z);
				val ms = r.next();
				val px = r.next();
				val py = r.next();
				val pz = r.next();
				val vx = r.next();
				val vy = r.next();
				val vz = r.next();
				
				init(i) = new Body(ms, px, py, pz, vx, vy, vz);
				z+=2;
				
		}

			/*maps the elements of the distributed array to the
			 * elements of  init and copies their values, 
			 * iterating over the distribution
			 */
			 
			 //executes in parallel at each place in the distribution
        	finish ateach(place in Dist.makeUnique()) { 
				
					//calculates where to start reading in the initial array
            		val startHere = here.id * chunkSize; 
            		
					//calculates where to stop reading the initial array
            		val endHere = Math.min(numBodies, (here.id+1) * chunkSize);	
					//calculates the total number of bodies this locale owns
            		val numBodiesHere = Math.max(0, endHere-startHere-1);
					//declares a local array
            		val bodiesHere = new Rail[Body](numBodiesHere+1);
            		var i:Int = 0;

			
					//iterates over the initial array, inside the calculated range and copies to the local array
            		for(gridPoint in startHere..(endHere-1)) {
			
				
						bodiesHere(i) = init(gridPoint);
						i++;
            		}
					//assigns the contents of the local array to the distributed array
            		bodies(here.id) = bodiesHere; 
        	}
	}


	/* The advance function performs the communication and 
	 * the calculation of the new velocities and positions of the bodies in the univers
	 * and returns the produced energy from the interactions
	 */
	public def Advance(dt:double):double{
		
	/* The SymReducer module sums up all 
	 * local energies calculated at each place
	 */
	 	
	val directEnergy =  finish(mySumReducer()){ 

		//executes in parallel for each place
		ateach(pl in bodies) {
					//myBodies: local copy of the distributed array with the current place's elements 
                	val myBodies : Rail[Body] = bodies(pl);
			
					//toSent: copy of myBodies for exchange with the other places
                   	val toSent = new Rail[Body](myBodies.size as Int, (i:Int)=>new Body(myBodies(i).mass,myBodies(i).posx, myBodies(i).posy, myBodies(i).posz, myBodies(i).velx, myBodies(i).vely, myBodies(i).velz));
					var energyThisPlace: Double =0.0;

					//finds the next place
                  	val nextPlace = here.next();
                  	
                  	/* Communication between places ios performed by writing in the otherBodies distributed array
                  	 * in the position of teh target place
                  	 */
                  
                   	if (nextPlace != here) {	
                     		@Uncounted at(nextPlace) async {
                        		 atomic {
                              			  otherBodies(nextPlace.id)(pl) = toSent;
                           		 	}
                        	}
                   	}
			
				//calculates the interactions within this place
                 	for (i in 0..(myBodies.size-1)) {
							val bodyI = myBodies(i);
				
							val en1 = energy1(bodyI);
			
							energyThisPlace+=en1; //-+???

                      		for (j in 0..(i-1)) {
								val bodyJ = myBodies(j);

								val dx: double = bodyI.posx - bodyJ.posx;
								val dy: double = bodyI.posy - bodyJ.posy;
								val dz: double = bodyI.posz - bodyJ.posz;
						
                            	var d2: double  = dx*dx + dy*dy + dz*dz;
								//updates my bodies' velocity
								if (d2 != 0.0 ) 
								{ 
									var mag: double  = dt/ (d2*Math.sqrt(d2));

									bodyI.velx -= dx* bodyJ.mass * mag;
									bodyJ.velx += dx* bodyI.mass * mag;
									bodyI.vely -= dy* bodyJ.mass * mag;
									bodyJ.vely += dy* bodyI.mass * mag;
									bodyI.velz -= dz* bodyJ.mass * mag;
									bodyJ.velz += dz* bodyI.mass * mag;
						
									val e2 = energy2(bodyI, bodyJ, d2);
									energyThisPlace+= e2; 
					
								}
							}
					}
					//if there is only one place updates the bodies positions
					if (Place.MAX_PLACES ==1){
					
							for (i in 0..(myBodies.size-1)) {
					
								myBodies(i).posx += dt* myBodies(i).velx;
								myBodies(i).posy += dt* myBodies(i).vely;
								myBodies(i).posz += dt* myBodies(i).velz;
					
							}
					}
	
						//calculates new target(to write) and source(to read from) 
						var target : Place = nextPlace.next();
                    	var source : Place = here.prev();
                    	
                    /* The while loop will terminate when each place has received bodies from all
                     * other places and the source place to read from is themselves                   
                     */	
					while (source != here) {
						
                        	if (target != here) {
                            		// sending toSent to the next target place
                            		val targetPlace = target;
                           		@Uncounted at(targetPlace) async {
                                			atomic {
                                    				otherBodies(targetPlace.id)(pl) = toSent;
                                			}
                            		}
                        	}
				// waits on receipt of a set of bodies from source place
				when(otherBodies(here.id)(source.id) != null);

				//calculates all interactions with otherBodies at other place
				val other = otherBodies(here.id)(source.id);
				for (j in 0..(other.size-1)) {
					val bodyJ= other(j);
					for (i in 0..(myBodies.size-1)) {
						val bodyI = myBodies(i);					
						
						val dx: double = bodyI.posx - bodyJ.posx;
						val dy: double = bodyI.posy - bodyJ.posy;		
						val dz: double = bodyI.posz - bodyJ.posz;						
						var d2: double  = dx*dx + dy*dy + dz*dz;						
						//updates myBodies' velocities
						if (d2 != 0.0 ) { 
							var mag: double  = dt/ (d2*Math.sqrt(d2));

							bodyI.velx -= dx* bodyJ.mass * mag; 
							bodyI.vely -= dy* bodyJ.mass * mag; 
							bodyI.velz -= dz* bodyJ.mass * mag; 

							val e3 = energy2(bodyI, bodyJ, d2);
			
							energyThisPlace +=e3/2; 
						}	
					}
				}
			
				//updates my bodies' positions 
				for (i in 0..(myBodies.size-1)) {
						myBodies(i).posx += dt* myBodies(i).velx;
						myBodies(i).posy += dt* myBodies(i).vely;
						myBodies(i).posz += dt* myBodies(i).velz;
					
				}
				//calculates the next target and source place
				target = target.next();
				source = source.prev();
			}
			offer energyThisPlace; //contributes the energy of the place to the total energy
			
		}//ateach

	};//energy
	
	return directEnergy;
   	}//advance

	
	
	//printing function
	public def printBodies(){
				
		for(p1 in bodies) at(bodies.dist(p1)) {
				val bodiesHere = bodies(p1);
				for (i in 0..(bodiesHere.size-1)) 
				{
					val body = bodiesHere(i);
					body.printBody();
										
				}
		}
	}
			
			
	//calculates the energy between two bodies residing in teh same place	
	public def energy1(b:Body):double {
		return 0.5*b.mass * (b.velx*b.velx + b.vely*b.vely + b.velz*b.velz);
	}
	//calculates the energy between two bodies from different places
	public def energy2(b1:Body, b2:Body, d:double):double {
		return (b1.mass*b2.mass)/Math.sqrt(d);
	}

	/* module that reduces the energy values and sums the
	 * energy from all places
	 */
	static struct mySumReducer implements Reducible[Double] {
        	public def zero() = 0.0;
        	public operator this(a:Double, b:Double) = (a + b);
    	}
}

