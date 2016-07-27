/*
 * Implements the Body class and contains the constructor and some helper functions
 * 
 * Author: Konstantina Panagiotpoulou
 */


use Random;

class Body {

	
	var mass: real; //body's mass
	var posx, posy, posz : real; //body's position on x,y.z axis
	var velx, vely, velz : real; //body's velocity on x,y.z axis
	
	//default constructor
	proc Body(){

		mass = 1.1;
		posx = 1.1;
		posy = 1.1;
		posz = 1.1;
		velx = 1.1;
		vely = 1.1;
		velz = 1.1;
		
	}

	//constructor
	proc Body( mass: real, posx: real, posy: real, posz: real, velx: real, vely: real, velz : real){ 

	
		this.mass = mass;
		this.posx = posx;
		this.posy = posy;
		this.posz = posz;
		this.velx = velx;
		this.vely = vely;
		this.velz = velz;

	}

	//helper functions
	proc getMass(): real{return mass;}
	proc setMass(mass: real){this.mass=mass;}

	proc getPosX(): real{ return posx;}
	proc setPosX(posx: real){this.posx=posx;}

	proc getPosY(): real{ return posy;}
	proc setPosY(posy: real){this.posy=posy;}

	proc getPosZ(): real{ return posz;}
	proc setPosZ(posz: real){this.posz=posz;}

	proc getVelX(): real{ return velx;}
	proc setVelX(velx: real){this.velx=velx;}

	proc getVelY(): real{ return vely;}
	proc setVelY(vely: real){this.vely=vely;}
	
	proc getVelZ(): real{ return velz;}
	proc setVelZ(velz: real){this.velz=velz;}
	

	//printing function
	proc printBody(){

		writeln("mass: ", this.getMass(), "|| X: ", this.getPosX(), "|| Y: ", this.getPosY(), "|| Z: ", this.getPosZ(), "\n velx: ", this.getVelX(), "|| vely: ", this.getVelY(), "|| velz: ", this.getVelZ() );


	}

	//checks if two bodies are equal
	proc equals(b: Body):bool{
		if (this.mass == b.getMass() && this.posx==b.getPosX() && this.posy==b.getPosY() && this.posz==b.getPosZ()) then 
			{return true;}
		else {return false;}
	}


}
