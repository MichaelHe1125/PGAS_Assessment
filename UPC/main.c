#include <upc.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <upc_relaxed.h> 
#include <sys/types.h>
#include <time.h>

#define numBodies 3000*THREADS

#define chunk 3000
/*
 * export PATH=/PATH/TO/UPC/bin:$PATH]
 * upcc --pthreads -o main main.c
 * export UPC_PTHREADS_PER_PROC=1
 * upcrun -n=1 main
 * or
 * for ((n=1; n<9; n++)) ; do  upcrun -n=$n v4 555555 ; done
 * 
 * export PATH=/PATH/TO/UPC/bin:$PATH
 * export UPC_NODEFILE="/PATH/TO/HOST/FILE"
 * upcc -network=udp -pthreads=4 -o main main.c  //4 hosts in the host file
 * export UPC_PTHREADS_PER_PROC=1 //8-core per node available
 * upcrun -n=8 first 1
 * 
 * */

	struct Body {
 		 double posx, posy, posz;
 		 double velx, vely, velz;
 		 double mass;
	};


	
	shared [*] struct Body bodies[numBodies]; //[chunk]; //shared array -- block dist

	shared [*] struct Body otherBodies[THREADS][chunk]; 

	 double myRandom(int seed) {
		double x = seed;
		return x;
		
	}
	
	double next(double x){
		
		
		x = fmod(0.456*x + 0.34 ,65386.0);
		return x;
	}

	void init(){
		int z  = 2001;
		
		for (int i=0; i<numBodies; i++){
			double r = myRandom(z); 
			shared struct Body * b = (shared struct Body *)&(bodies[i]);
			
			b->mass = next(r); 
			b->posx =next(b->mass);  
			b->posy =next(b->posx);  
			b->posz =next(b->posy);   
			b->velx =next(b->posz);   
			b->vely =next(b->velx);  
			b->velz =next(b->vely);
			z+=2;  
		}
		
	}

	///energy functions
	double energy1(struct Body *b){
		return 0.5*b->mass * (b->velx*b->velx + b->vely*b->vely + b->velz*b->velz);
	}
	double energy2(struct Body *b1, struct Body *b2, double d){
		return (b1->mass*b2->mass)/sqrt(d);
	}

	double advance(double dt, int verbose, int debug){
		double energyThisPlace =0.0;
		upc_forall(int i=0; i<THREADS; i++; i)
		{
			
			int zz= 0;
			struct Body myBodies[chunk];

			struct Body toSent[chunk];


			for (int j=0; j<chunk; j++)
			{
				myBodies[j] = bodies[MYTHREAD*chunk+j];
			}

			//upc_barrier;
			if (verbose==1){
				if (MYTHREAD==0){printf("\n========MY INITIAL-BODIES====== ");}
				for (int j=0;j<chunk;j++){
					struct Body * b = &(myBodies[j]);
					printf("\nBODY: mass: %f || X: %f || Y: %f  || Z:  %f  velx: %f || vely: %f || velz: %f ---THREAD: %d ",
						 b->mass, b->posx, b->posy, b->posz, b->velx, b->vely, b->velz, MYTHREAD);
				}
			}
			
			upc_barrier;
			//copy myBodies to toSent
			for (int j=0; j<chunk; j++){
				toSent[j] = myBodies[j];
	
			}
	

			// before starting computation, send my bodies (toSent) to the next place
			int me = MYTHREAD;
			int next = me+1;
			if(next==THREADS){next=0;}
		
			//upc_barrier;


                   	if (next!= me ){
				for (int j=0; j<chunk; j++) 
				{       		
                              		otherBodies[next][j] = toSent[j];
				}
                   	}

			for (int i=0; i<chunk; i++){ 
		
    				struct Body * bI = &(myBodies[i]);
				//energy
				double en1 = energy1(bI);
				energyThisPlace+=en1; 

    				for (int j=i+1; j<chunk; j++){  

      					struct Body * bJ = &(myBodies[j]);
					

      					double dx = bI->posx - bJ->posx;
      					double dy = bI->posy - bJ->posy;
      					double dz = bI->posz - bJ->posz;

      					double distance = sqrt(dx * dx + dy * dy + dz * dz);
						
					if(distance != 0.0 ){
     						double mag = dt / (distance * distance * distance);

      						bI->velx -= dx * bJ->mass * mag;
     						bI->vely -= dy * bJ->mass * mag;
      						bI->velz -= dz * bJ->mass * mag;

      						bJ->velx += dx * bI->mass * mag;
      						bJ->vely += dy * bI->mass * mag;
      						bJ->velz += dz * bI->mass * mag;
						//energy
						//if (THREADS ==1){
						double e2 = energy2(bI, bJ, distance);
						energyThisPlace+= e2; 
						//}
					}
    				}
  			}

			//update Bodies
			if (THREADS==1){
  				for (int i=0; i<chunk; i++){
    					struct Body * b = &(myBodies[i]);

    					b->posx += dt * b->velx;
    					b->posy += dt * b->vely;
    					b->posz += dt * b->velz;
  				}

				if (verbose==1){
					printf("\n");	
					for (int j=0;j<chunk;j++){
						struct Body * b = &(myBodies[j]);
						printf("========MY-UPDATED-BODIES======I am : %d and myBody in position %d is: mass: %f || X: %f || Y: %f  || Z:  %f  velx: %f || vely: %f || velz: %f --: %d\n ",MYTHREAD, j, b->mass, b->posx, b->posy, b->posz, b->velx, b->vely, b->velz);
					}

					printf("\n");
				}
			}
			int target = next + 1;
                    	int source = me -1;


			if(target==THREADS){target=0;}
			if(source<0){source=THREADS-1;}

			//upc_barrier;
		        while (source != me) {
                        	if (target != me) {
                            		// send myBodies (toSent) to the next target place
                            		for (int j=0; j<chunk; j++) 
					{       		
                              			otherBodies[target][j] = toSent[j];
					}
                                    	
                                			
                        	}
				
				// wait on receipt of a set of bodies from other place
				shared struct Body *ot = (shared struct Body *)&(otherBodies[me][chunk-1]);
				
				if (ot == NULL){ 
					
					while (&(otherBodies[me][chunk-1]) == NULL){
						
					}
				}
				//upc_barrier;

				//all interactions with otherBodies at other place
				for (int j=0; j<chunk; j++){//in 0..(other.size-1)) {
					shared struct Body *bJ= (shared struct Body *)&(otherBodies[me][j]);
					for (int i=0; i<chunk; i++){ // in 0..(myBodies.size-1)) {
						struct Body *bI = &(myBodies[i]);					
						double dx = bI->posx - bJ->posx;
      						double dy = bI->posy - bJ->posy;
      						double dz = bI->posz - bJ->posz;

      						double distance = sqrt(dx * dx + dy * dy + dz * dz);						
						//update my bodies' velocity
						if (distance != 0.0 ) { 
							double mag = dt / (distance * distance * distance);

      							bI->velx -= dx * bJ->mass * mag;
     							bI->vely -= dy * bJ->mass * mag;
      							bI->velz -= dz * bJ->mass * mag;
							//energy
							double e3 = energy2(bI, (struct Body *)bJ, distance);
							energyThisPlace +=e3/2; 
						}	
					}
				}
			
				//update my bodies' position 
				for (int i=0; i<chunk; i++){
    					struct Body * b = &(myBodies[i]);

    					b->posx += dt * b->velx;
    					b->posy += dt * b->vely;
    					b->posz += dt * b->velz;
  				}
				//upc_barrier;
				
				target = target+1;
				if(target ==THREADS){ target=0;} 
				source = source -1;
				if(source<0){source = THREADS-1;}

			}

			//upc_barrier;
			if (verbose==1){	
				if (MYTHREAD==0){printf("\n========MY-UPDATED-BODIES====== ");}
				
				for (int j=0;j<chunk;j++){
					struct Body * b = &(myBodies[j]);
					printf("\nBODY: mass: %f || X: %f || Y: %f  || Z:  %f  velx: %f || vely: %f || velz: %f ---THREAD: %d ", b->mass, b->posx, b->posy, b->posz, b->velx, b->vely, b->velz, MYTHREAD);
				}
			}
			
		}//upcforall
		
		return energyThisPlace;
	}//advance

	int main(int argc, char ** argv)
	{
  		int numIterations = atoi(argv[1]); //numIterations
	
  		//printf("BODIES : %d\n", numBodies);
		
		int verbose = atoi(argv[2]);
		int debug = 0;
		double dt = 0.1;

		double totalEnergy =0.0;
		clock_t begin, end;
		double time_spent;

		init();
		

		if (MYTHREAD==0){
			begin = clock();
		}
		for(int i =0; i<numIterations; i++){
			totalEnergy+= advance(dt, verbose, debug);
		}
		if (MYTHREAD==0){
			end = clock();
			time_spent = (double)(end - begin)/ CLOCKS_PER_SEC;
			printf("\n Total time: %f seconds", time_spent ); //(int) t2-t1);
			printf("\n ");
			printf("\nTotal energy: %f", totalEnergy );
		}
  		return 0;
}

	// print
	int print(){
		
		upc_forall(int i=0; i<numBodies; i++; &bodies[i]){
			shared struct Body * bb = (shared struct Body *)&(bodies[i]);
    
            		printf("\nmass: %f || X: %f || Y: %f  || Z:  %f  velx: %f || vely: %f || velz: %f --from : %d\n ", bb->mass, bb->posx, bb->posy, bb->posz, bb->velx, bb->vely, bb->velz, MYTHREAD);

			
    		
		}
		return 0;
	}
	
