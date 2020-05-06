/***
* Name: AutonomousCovidCommunity
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model AutonomousCovidCommunity

/* Insert your model definition here */

global{
	bool autonomy;
	float crossRatio<-0.1;
	bool drawTrajectory<-true;
	int trajectoryLength<-100;
	float trajectoryTransparency<-0.25;
	float peopleTransparency<-0.5;
	float macroTransparency<-0.5;
	int nbBuildingPerDistrict<-10;
	int nbPeople<-100;
	float step<-1#sec;
	int current_hour update: (time / #hour) mod 24;
	int current_day  update: (int(time/#day));
	float districtSize<-250#m;
	float buildingSize<-40#m;
	geometry shape<-square (1#km);
	string cityScopeCity<-"volpe";
	file district_shapefile <- file("./../../includes/AutonomousCities/district.shp");
	rgb conventionalDistrictColor <-rgb(225,235,241);
	rgb autonomousDistrictColor <-rgb(39,62,78)+50;
	rgb macroGraphColor<-rgb(245,135,51);
	rgb backgroundColor<-rgb(39,62,78);
	map<string, rgb> buildingColors <- ["residential"::rgb(168,192,208), "shopping"::rgb(245,135,51), "business"::rgb(217,198,163)];
	map<string, geometry> buildingShape <- ["residential"::circle(buildingSize/2), "shopping"::square(buildingSize) rotated_by 45, "business"::triangle(buildingSize*1.25)];
	
	map<string,float> proportion_per_type<-["homeWorker"::0.2,"OfficeWorker"::0.6,"ShopWorker"::0.2];
	map<string,rgb> color_per_type<-["homeWorker"::rgb(240,255,56),"OfficeWorker"::rgb(82,171,255),"ShopWorker"::rgb(179,38,30)];
	

	graph<district, district> macro_graph;
	bool drawMacroGraph<-false;
	bool pandemy<-false;	
	//COVID Related
	bool reinit<-false;
	
	init{	
		create district from:district_shapefile{
			create building number:nbBuildingPerDistrict{
			  shape<-square(20#m);
			  location<-any_location_in(myself.shape*0.9);
			  myself.myBuildings<<self;
			  myDistrict <- myself;
		    }
		}
		
		macro_graph<- graph<district, district>(district as_distance_graph (500#m ));
		do updateSim(autonomy); 
	}
	
	reflex updateStep{
		if(step > 1#sec){
			step<-step-1#sec;
		}
	}
	
	action updateSim(bool _autonomy){
		step<-60#sec;
		do updateDistrict(_autonomy);
		do updatePeople(_autonomy);
		reinit<-true;
	}

	action updatePeople(bool _autonomy){
		ask people{
			do die;
		}
		create people number:nbPeople{
		  	current_trajectory <- [];
		  	color<-rgb(125)+rnd(-125,125);
		  	type <- proportion_per_type.keys[rnd_choice(proportion_per_type.values)];
		}
		if (!_autonomy){
		  ask people{
			myHome<-one_of(building where (each.type="residential"));
			myShop<-one_of(building where (each.type="shopping"));
			myOffice<-one_of(building where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
			myCurrentDistrict<- myPlaces[0].myDistrict;
		  }	
		}
		else{
		  ask people{
		  	myCurrentDistrict<-one_of(district);
			myHome<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myShop<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myOffice<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
		  }
		  ask (length(people)*crossRatio) among people{
		  	myCurrentDistrict<-one_of(district);
			myHome<-one_of(myCurrentDistrict.myBuildings where (each.type="residential"));
			myCurrentDistrict<-one_of(district);
			myShop<-one_of(myCurrentDistrict.myBuildings where (each.type="shopping"));
			myCurrentDistrict<-one_of(district);
			myOffice<-one_of(myCurrentDistrict.myBuildings where (each.type="business"));
			my_target<-any_location_in(myPlaces[0]);
		  }		
		}
		ask people{
			if (type = proportion_per_type.keys[0]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myHome;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myHome;
				myPlaces[4]<-myHome;
			}
			if (type = proportion_per_type.keys[1]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myOffice;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myOffice;
				myPlaces[4]<-myHome;
			}
			if (type = proportion_per_type.keys[2]){
				myPlaces[0]<-myHome;
				myPlaces[1]<-myShop;
				myPlaces[2]<-myShop;
				myPlaces[3]<-myShop;
				myPlaces[4]<-myHome;
			}
		}		
}


action updateDistrict( bool _autonomy){
	if (!_autonomy){
		ask first(district where (each.name = "district0")){
			isAutonomous<-false;
			conventionalType<-"residential";
			ask myBuildings{
				type<-"residential";
			}
		}
		ask first(district where (each.name = "district1")){
			isAutonomous<-false;
			conventionalType<-"shopping";
			ask myBuildings{
			  type<-"shopping";
			}
		}
		ask first(district where (each.name = "district2")){
			isAutonomous<-false;
			conventionalType<-"business";
			ask myBuildings{
			  type<-"business";	
			}
		}
	}
	else{
		ask district{
			isAutonomous<-true;
			ask myBuildings{
				type<-flip(0.3) ? "residential" : (flip(0.3) ? "shopping" : "business");
			}
			if(length (myBuildings where (each.type="residential"))=0){
				ask one_of(myBuildings){
				  type<-"residential";	
				}		
			}
			if(length (myBuildings where (each.type="shopping"))=0){
				ask one_of(myBuildings){
				  type<-"shopping";	
				}		
			}
			if(length (myBuildings where (each.type="business"))=0){
				ask one_of(myBuildings){
				  type<-"business";	
				}		
			}
		}
	}	
}	
}

species district{
	list<building> myBuildings;
	bool isQuarantine<-false;
	bool isAutonomous<-false;
	string conventionalType;
	aspect default{
		//draw string(self.name) at:{location.x+districtSize*1.1,location.y-districtSize*0.5} color:#white perspective: true font:font("Helvetica", 30 , #bold);
		if (isQuarantine){
			draw shape*1.1 color:rgb(#red,1) empty:true border:#red;
		}
		if(isAutonomous){
			draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:autonomousDistrictColor border:autonomousDistrictColor-50;
			draw shape color:conventionalDistrictColor border:conventionalDistrictColor-50;
		}else{
			draw (shape*1.05)-shape at_location {location.x,location.y,-0.01} color:buildingColors[conventionalType] border:buildingColors[conventionalType]-50;
			draw shape color:conventionalDistrictColor border:buildingColors[conventionalType]-50;
		}
		
	}
}



species building{
	rgb color;
	string type;
	district myDistrict;
	aspect default{
		draw buildingShape[type] at: location color:buildingColors[type] border:buildingColors[type]-50;
	}
}

species people skills:[moving]{
	rgb color;
	building myHome;
	building myOffice;
	building myShop;
	string type;
	list<building> myPlaces<-[one_of(building),one_of(building),one_of(building),one_of(building),one_of(building)];
	point my_target;
	int curPlaces<-0;
	list<point> current_trajectory;
	district myCurrentDistrict;
	district target_district;
	bool go_outside <- false;
	bool isMoving<-true;
	bool macroTrip<-false;
	bool isQuarantine<-false;
	
	reflex move_to_target_district when: (target_district != nil and isMoving){
		if (go_outside) {
			macroTrip<-false;
			do goto target: myCurrentDistrict.location speed:5.0;
			if (location = myCurrentDistrict.location) {
				go_outside <- false;
				
			}
		} else {
			macroTrip<-true;
			do goto target: target_district.location  speed:10.0;
			if (location = target_district.location) {
				myCurrentDistrict <- target_district;
				target_district <- nil;
			}
		}
	}
	reflex move_inside_district when: (target_district = nil and isMoving){
	    macroTrip<-false;
	    do goto target:my_target speed:5.0;
    	if (my_target = location){
    		curPlaces<-(curPlaces+1) mod 5;
			building bd <- myPlaces[curPlaces];
			my_target<-any_location_in(bd);
			if (bd.myDistrict != myCurrentDistrict) {
				go_outside <- true;
				target_district <- bd.myDistrict;
			}
		}
		
    }
    
    reflex ManageQuarantine when: !isMoving{
    	macroTrip<-false;
    	if(isQuarantine=false){
    	  do goto target:myPlaces[0] speed:5.0;	
    	}
    	if(location=myPlaces[0].location and isQuarantine=false){
    		location<-any_location_in(myPlaces[0].shape);
    		isQuarantine<-true;
    	}
    }
    
    reflex computeTrajectory{
    	loop while:(length(current_trajectory) > trajectoryLength){
	    		current_trajectory >> first(current_trajectory);
       		}
        	current_trajectory << location;
    }
    
    reflex rnd_move {
    	do wander speed:0.1;
    }
	
	aspect default{
		draw circle(4#m) color:rgb(color,peopleTransparency);
		if(macroTrip){
			draw square(15#m) color:rgb(color,macroTransparency);
		}
		if(drawTrajectory){
			draw line(current_trajectory)  color: rgb(color,trajectoryTransparency);
		}
	}
	
	aspect profile{
		draw circle(4#m) color:color_per_type[type];
	}
}

experiment City{
	float minimum_cycle_duration<-0.02;
	parameter "Autonomy" category:"Policy" var: autonomy <- false  on_change: {ask world{do updateSim(autonomy);}} enables:[crossRatio] ;
	parameter "Cross District Autonomy Ratio:" category: "Policy" var:crossRatio <-0.1 min:0.0 max:1.0 on_change: {ask world{do updateSim(autonomy);}};
	parameter "Trajectory:" category: "Visualization" var:drawTrajectory <-true ;
	parameter "Trajectory Length:" category: "Visualization" var:trajectoryLength <-100 min:0 max:100 ;
	parameter "Trajectory Transparency:" category: "Visualization" var:trajectoryTransparency <-0.25 min:0.0 max:1.0 ;
	parameter "People Transparency:" category: "Visualization" var:peopleTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Macro Transparency:" category: "Visualization" var:macroTransparency <-0.5 min:0.0 max:1.0 ;
	parameter "Draw Inter District Graph:" category: "Visualization" var:drawMacroGraph <-false;
    //parameter "Simulation Step"  category: "Simulation" var:step min:1#sec max:60#sec step:1#sec;
	
	output {
		display GotoOnNetworkAgent type:opengl background:backgroundColor draw_env:false synchronized:true toolbar:false
		camera_pos: {417.1411,527.07,2064.3239} camera_look_pos: {417.1411,527.0339,-5.0E-4} camera_up_vector: {0.0,1.0,0.0}
		
		{
			overlay position: { 0, 25 } size: { 240 #px, 680 #px } background: #black border: #black {				    
		      draw !autonomy ? "Conventional" : "Autonomy" color:#white at:{50,100} font:font("Helvetica", 25 , #bold);
		      loop i from:0 to:length(buildingColors)-1{
				draw buildingShape[buildingColors.keys[i]]*0.5 empty:false color: buildingColors.values[i] at: {75, 150+i*50};
				draw buildingColors.keys[i] color: buildingColors.values[i] at:  {120, 160+i*50} perspective: true font:font("Helvetica", 25 , #plain);
			  }
			  
			  loop i from:0 to:length(proportion_per_type)-1{
				draw circle (5)  empty:false color: color_per_type.values[i] at: {75, 350+i*50};
				draw proportion_per_type.keys[i] + " (" + proportion_per_type.values[i]+")" color: color_per_type.values[i] at:  {120, 360+i*50} perspective: true font:font("Helvetica", 15 , #plain);
			  }
			}
			
			species district position:{0,0,-0.001};
			species building;
			
			
			graphics "macro_graph" {
				if (macro_graph != nil and drawMacroGraph) {
					loop eg over: macro_graph.edges {
						geometry edge_geom <- geometry(eg);
						float w <- macro_graph weight_of eg;
						if(!autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 10#m color:macroGraphColor;	
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: 10#m color:macroGraphColor;	
						}
						if(autonomy){
							//draw curve(edge_geom.points[0],edge_geom.points[1], 0.5, 200, 90) width: 2#m color:macroGraphColor;
						  draw line(edge_geom.points[0],edge_geom.points[1]) width: 2#m + crossRatio*8#m color:macroGraphColor;	
						}
						
					}

				}
			}
			
			
			graphics 'City Efficienty'{
			  float nbWalk<-float(length (people where (each.macroTrip= false)));
			  float nbMass<-float(length (people where (each.macroTrip= true)));
			  float spacebetween<-0.5; 	
				 //CITY EFFICIENTY
			  point posCE<-{1200,100};
			  draw rectangle(320*1.5,200*1.5) at:posCE color:#white empty:true;
			  
			  
			  draw rectangle(nbWalk,10) color: #green at: {posCE.x-50+nbWalk/2, posCE.y+0*100};
			  draw "Walk: " + nbWalk/length(people) color: #green at:  {posCE.x-50, -20+posCE.y+0*100} perspective: true font:font("Helvetica", 20 , #bold);
			  draw circle(10) color: #green at: {posCE.x+120, posCE.y+0*100-30};
			  
			  draw rectangle(nbMass,10) color: #red at: {posCE.x-50+nbMass/2, posCE.y+spacebetween*100};
			  draw "Mass: " + nbMass/length(people)color: #red at:  {posCE.x-50, -20+posCE.y+spacebetween*100} perspective: true font:font("Helvetica", 20 , #bold);
			  draw square(20) color: #red at: {posCE.x+120, posCE.y+0*100-30+spacebetween*100};
			  
			  draw rectangle(55,155) color: #white empty:true at: {posCE.x-100, posCE.y+spacebetween*100 - 150/2};
			  draw rectangle(50,(nbWalk/100)*150) color: #green at: {posCE.x-100, posCE.y+spacebetween*100 - ((nbWalk/100))*150/2};
			  draw "City Efficiency: " + int((nbWalk)) color: #white at:  {posCE.x-100-25, 10+posCE.y+2*spacebetween*100} perspective: true font:font("Helvetica", 20 , #bold);
			}
			species people aspect:profile;
			event["c"] action: {autonomy<-false;ask world{do updateSim(autonomy);}};
			event["a"] action: {autonomy<-true;ask world{do updateSim(autonomy);}};
		}
		
	}
}

