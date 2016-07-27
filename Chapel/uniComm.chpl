/*
 * Implements the main class which performs the interaction and energy calculations
 * 
 * Author: Konstantina Panagiotpoulou
 */

use Time;
use Body;
use Random;
use Math;
use BlockDist;
use myRandom;


config var numBodies: int = 10;                          //total number of bodies in the univerce
config var numIterations:int = 120;                     // number of iterations
config var debug, debug2, verbose : bool = false;       //debuging and printing controls

var dimensions: (real, real);                           //dimensions of the universe
var dt: real = 0.1;                                     //interval of iterations
const D = {0..(numBodies-1)};                           //domain of total number of bodies
const ddom = D dmapped Block(boundingBox=D);            //Block distribution of domain D

var chunk = numBodies /numLocales;                      //calculates the chunk size assigned to each locale
if (mod(numBodies, numLocales)>0){ chunk = chunk+mod(numBodies, numLocales);}
var ch =  {1..chunk};
var bodies:[ddom][ch] Body;                             //the distributed array of bodies
var otherBodies:[ddom][D][ch]Body;                      //The distributed array which stores the bodies of remote locales
var syncs:[ddom] sync int;                              //distributed array of sync variables

var tinit: Timer;
tinit.start();

//initial non-distributed array initialised with random values
var init: [D] Body ; 
	
var z:int  = 2001;
for i in D {
		
  var r = new myRandom(z);
  var ms = r.next();
  var px = r.next();
  var py = r.next();
  var pz = r.next();
  var vx = r.next();
  var vy = r.next();
  var vz = r.next();
  init(i) = new Body(ms, px, py, pz, vx, vy, vz);
  z+=2;
}

//executes on all locales in parallel
coforall loc in Locales do  
  on loc {
    //returns the indices owned on the urrent locale
    const myInds = ddom._value.locDoms[here.id].myBlock;
    var bodiesHere:[ch] Body;
    var i:int = 1;
    //iterates over myInds and copies the values from the initial array
    for gridPoint in myInds{
	bodiesHere(i) = init(gridPoint);
	i+=1;
    }
    bodies(here.id) = bodiesHere;
  }
  tinit.stop();
  
  //prints the initial positions of the bodies in the universe
  if (verbose){
	writeln("initial positions");
	forall loc in Locales do
          on loc {
		var bo = bodies(here.id);
		for b in bo{
	            if(b!=nil){
			b.printBody();
			writeln("---IN PLACE: ", here.id, " with name : ", here.name);
		    }
		}
	  }
   }
	
  //starts the timer
  var t: Timer;
  var energy = 0.0;
  t.start();

  //executes on all locales in parallel
  coforall loc in Locales do  
	on loc {
	  var energyThisPlace= 0.0;
  	  const myInds = ddom._value.locDoms[here.id].myBlock;
			
	  var mydom = {0..(myInds.size -1)};
          //copies the bodies of the current locale to a local array
          var myBodies = bodies(here.id);
	  //prepares a local array to sent to the other locales
	  var toSent :[ch] Body = myBodies;

    	  if (debug2){
            writeln("MYBODIES from : ", here.id);
	    for mb in myBodies{
	      if(mb!=nil){
	        writeln("I am: ",here.id);
	        mb.printBody();
	      }
	    }

  	  writeln("MYTOSENT from : ", here.id);
          for mb in toSent{
	    if(mb!=nil){
		writeln("I am: ",here.id);
		mb.printBody();
	    }
	  }
	}

	// before starting computation, send my bodies (toSent) to the next place

	var me = here.id; //identifies the ciurrent locale
	var nextPlace = here.id+1; //calculates the next one
	if(nextPlace ==numLocales){ nextPlace=0;} //bound check			
	var mydd = mydom;
       	if (nextPlace!= me ){ 
	  //shifts to the nextPlace and writes the toSent array
          on Locales[nextPlace]{
	    otherBodies(nextPlace)(me) = toSent;
	    //assigns a value to the sync variable
	    syncs(nextPlace) = 1;
	  }
         
        }
			

	//calculates the energy for all interactions within this place
        for i in 1..myInds.size {
	  var bodyI = myBodies(i);
	  var en1 = energy1(bodyI);
		
	  energyThisPlace+=en1; 
	  var ch2= {1..(i-1)};
          for j in ch2 {
	    var bodyJ = myBodies(j);

	    var dx: real = bodyI.posx - bodyJ.posx;
	    var dy: real = bodyI.posy - bodyJ.posy;
	    var dz: real = bodyI.posz - bodyJ.posz;
	    var d2: real  = dx*dx + dy*dy + dz*dz;
	    //updates my bodies' velocity
	    if (d2 != 0.0 ) 
	    { 
		
	      var mag: real  = dt/ (d2*sqrt(d2));

	      bodyI.velx -= dx* bodyJ.mass * mag;
	      bodyJ.velx += dx* bodyI.mass * mag;
	      bodyI.vely -= dy* bodyJ.mass * mag;
	      bodyJ.vely += dy* bodyI.mass * mag;
	      bodyI.velz -= dz* bodyJ.mass * mag;
	      bodyJ.velz += dz* bodyI.mass * mag;
		
	      var e2 = energy2(bodyI, bodyJ, d2);
	      energyThisPlace+= e2; ///-+???
	
	    }
			
	  }
	}
		
        //if there is only one locale, update mybodies' position 
	if (numLocales ==1){
				
	  for i in 1..myInds.size {
	    var bodyI = myBodies(i);
	    bodyI.posx += dt* bodyI.velx;
	    bodyI.posy += dt* bodyI.vely;
	    bodyI.posz += dt* bodyI.velz;
	  }
	  
        }
	
        //calculates the new target and source locale and performs bound checks
	var target =nextPlace + 1;
	if(target ==numLocales){target=0;} 
	var source = me - 1;	
	if(source<0){source = numLocales-1;}
	//waits to receive friom source locale
	if (numLocales!=1){
	  //checks sync variable
	  if (syncs(me) ==1 ){
	    if(debug){writeln("PROCEEDing.. I am ", here.id);}
	  }
	}
	/* The while loop terminates when the current locale has received from all the
	 * locales in the universe and the next source locale is
	 * itself
	 */
			
	 while (source != me) {
				
	  if (target != me) {
            // send myBodies (toSent) to the next target place
	    on Locales[target]{
              otherBodies(target)(me) = toSent;
            }	
          }
	  //calculates all interactions with otherBodies at other place
	  for j in ch{ 			
		var bodyJ= otherBodies(me)(source)(j);
		
		if (bodyJ !=nil){
	          //checks if the position is empty
                  for i in 1..myInds.size{ 			
		    var bodyI = myBodies(i);					
		    var dx: real = bodyI.posx - bodyJ.posx;
		    var dy: real = bodyI.posy - bodyJ.posy;		
		    var dz: real = bodyI.posz - bodyJ.posz;	
		    var d2: real  = dx*dx + dy*dy + dz*dz;						
		    //update my bodies' velocity
		    if (d2 != 0.0 ) { 
			var mag: real  = dt/ (d2*sqrt(d2));
			//only updates the positions of myBodies
			bodyI.velx -= dx* bodyJ.mass * mag; 
			bodyI.vely -= dy* bodyJ.mass * mag; 
			bodyI.velz -= dz* bodyJ.mass * mag; 
			var e3 = energy2(bodyI, bodyJ, d2);
				
			energyThisPlace +=e3/2; 
                    }	
		  }
		}//if (bodyJ !=nil){
	  }//for j in ch{
	
          //update my bodies' position 
	  for i in  1..myInds.size {
	    var bodyI = myBodies(i);
	    bodyI.posx += dt* bodyI.velx;
	    bodyI.posy += dt* bodyI.vely;
	    bodyI.posz += dt* bodyI.velz;
	  }
		
	  //calculates thje new target and source locale and performs bound checks
	  target = target+1;
	  if(target ==numLocales){target=0;} 
	  source = source -1;
	  if(source<0){source = numLocales-1;}
	}		
	energy+= energyThisPlace; //contributes teh energy of the place to the total energy
      }//coforall
        
      t.stop();

      //prints the final positions of teh bodies in the universe
      if (verbose){
      writeln("final positions");
      forall loc in Locales do
	on loc {
          var bo = bodies(here.id);
	  for b in bo{
	    if(b!=nil){
		b.printBody();
		writeln("---IN PLACE: ", here.id, " with name : ", here.name);
	    }
			
	  }
	}
      }
	

      writeln (" ");
      writeln ("Total energy: ", energy );

      writeln("Time elapsed: ", t.elapsed());
      writeln("Time initialisation: ", tinit.elapsed());

      //calculates the energy between two bodies residing on the same locale
      proc energy1(b:Body):real {
	return 0.5*b.mass * (b.velx*b.velx + b.vely*b.vely + b.velz*b.velz);
      }
      //calculates the energy between two bodies residing on different locales
      proc energy2(b1:Body, b2:Body, d:real):real {
	return (b1.mass*b2.mass)/sqrt(d);
      }
        
      

