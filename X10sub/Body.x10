/*
 * Implements the class Body, representing each body in the universe
 * Author: Konstantina Panagiotopoulou 2013
 */

import x10.util.Random;
import x10.io.Printer;


public class Body {

	public var mass: double;	//body's mass
	public var posx : double;	//body's position on x-axis
	public var posy : double;	//body's position on y-axis
	public var posz : double;	//body's position on z-axis
	public var velx : double;	//body's velocity on x-axis
	public var vely : double;	//body's velocity on y-axis
	public var velz : double;	//body's velocity on z-axis

	//default constructor
	public def this(){ 

		this.mass = 1.1;	
		this.posx = 1.1;
		this.posy = 1.1;
		this.posz = 1.1;
		this.velx = 1.1;
		this.vely = 1.1;
		this.velz = 1.1;
				
	}
	
	// constructor
	public def this(mass: double, posx: double, posy: double, posz: double, velx: double, vely: double, velz : double) { 
		
		this.mass = mass;	
		this.posx = posx;
		this.posy = posy;
		this.posz = posz;
		this.velx = velx;
		this.vely = vely;
		this.velz = velz;
	}

	
	//helper functions
	
	public def getMass(): double{return mass;}
	public def setMass(mass: double){this.mass=mass;}

	public def getPosX(): double{ return posx;}
	public def setPosX(posx: double){this.posx=posx;}

	public def getPosY(): double{ return posy;}
	public def setPosY(posy: double){this.posy=posy;}

	public def getPosZ(): double{ return posz;}
	public def setPosZ(posz: double){this.posz=posz;}

	public def getVelX(): double{ return velx;}
	public def setVelX(velx: double){this.velx=velx;}

	public def getVelY(): double{ return vely;}
	public def setVelY(vely: double){this.vely=vely;}
	
	public def getVelZ(): double{ return velz;}
	public def setVelZ(velz: double){this.velz=velz;}

	//print function
	public def printBody(){	

		Console.OUT.println("mass: "+this.getMass()+"|| X: "+this.getPosX()+"|| Y: "+this.getPosY()+"|| Z: "+this.getPosZ()+"\n velx: "+this.getVelX()+"|| vely: "+this.getVelY()+"|| velz: "+this.getVelZ()+" ---PLACE: "+here.id); //+"|| force: "+this.getForce());


	}

	
	public def equals(b: Body):Boolean{ // checks if two bodies are equal
		if (this.mass == b.getMass() && this.posx==b.getPosX() && this.posy==b.getPosY() && this.posz==b.getPosZ()) 
			{return true;}
		else {return false;}
	}

}	//class Body
	
