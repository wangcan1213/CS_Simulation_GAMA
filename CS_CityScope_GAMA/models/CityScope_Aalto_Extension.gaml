/***
* Name: CityScope_ABM_Aalto
* Author: Ronan Doorley and Arnaud Grignard
* Description: This is an extension of the orginal CityScope Main model.
* Tags: Tag1, Tag2, TagN
***/

model CityScope_ABM_Aalto

import "CityScope_main.gaml"

global{
	//GIS folder of the CITY	
	string cityGISFolder <- "./../includes/City/otaniemi";	
	
	// Variables used to initialize the table's grid position.
	float angle <- -9.74;
	point center <- {1600, 1000};
	float brickSize <- 24.0;
	float cityIOVersion<-2.1;
	bool initpop <-false;
	
	//	city_io
	string CITY_IO_URL <- "https://cityio.media.mit.edu/api/table/cs_aalto_2";
	// Offline backup data to use when server data unavailable.
	string BACKUP_DATA <- "../includes/City/otaniemi/cityIO_Aalto.json";
	
    //Sliders that dont exisit in Aalto table and are only used in version 1.0 
	int	toggle1 <- 2;
	int	slider1 <-2;
	// TODO: Hard-coding density because the Aalto table doesnt have it.
	list<float> density_array<-[1.0,1.0,1.0,1.0,1.0,1.0];
	
	// TODO: mapping needs to be fixed for Aalto inputs
	map<int, list> citymatrix_map_settings <- [-1::["Green", "Green"], 0::["R", "L"], 1::["R", "M"], 2::["R", "S"], 3::["O", "L"], 4::["O", "M"], 5::["O", "S"], 6::["A", "Road"], 7::["A", "Plaza"], 
		8::["Pa", "Park"], 9::["P", "Parking"], 20::["Green", "Green"], 21::["Green", "Green"]
	]; 
	

	// Babak dev:
	int max_walking_distance <- 300 	min:0 max:3000	parameter: "maximum walking distance form parking:" category: "people settings";
	
	float min_work_start_for_staff <- 8.0;
	float max_work_start_for_staff <- 10.0;
	
	float min_work_start_for_student <- 8.0;
	float max_work_start_for_student <- 14.0;
	
	float min_work_start_for_visitor <- 8.0;
	float max_work_start_for_visitor <- 14.0;
	

	
	float min_work_duration_for_staff <- 1.0;
	float max_work_duration_for_staff <- 7.0;
	
	float min_work_duration_for_student <- 1.0;
	float max_work_duration_for_student <- 7.0;
	
	float min_work_duration_for_visitor <- 0.5;
	float max_work_duration_for_visitor <- 2.0;	
	
	
	float min_work_end <- 17.0;
	float max_work_end <- 18.0;
	
	graph car_road_graph;
	graph pedestrian_road_graph;
	
	//USER GOUPS PARAMETERS:
	int count_of_staff <- 2000 min:0 max: 5000 parameter: "number of staff " category: 	"user group";
	int count_of_students <- 2000 min:0 max: 5000 parameter: "number of students" category: "user group";	
	int count_of_visitors <- 2000 min:0 max: 5000 parameter: "number of visitors during the day" category: "user group";
	
	int number_of_people <- count_of_staff + count_of_students + count_of_visitors ;
		
	file parking_footprint_shapefile <- file(cityGISFolder + "/parking_footprint.shp");
	file roads_shapefile <- file(cityGISFolder + "/roads.shp");
	file campus_buildings <- file(cityGISFolder + "/Campus_buildings.shp");
	file gateways_file <- file(cityGISFolder + "/gateways.shp");
	
	float step <- 1 #mn;
	int current_time update: (360 + time / #mn) mod 1440;
	
	int multiplication_factor <- 2;
		
	
	//checking time
	int clock_display;
	reflex clock_Min when:current_time != clock_display {clock_display <- current_time ; write(string(int(current_time/60)) + ":" + string(current_time mod 60) ) ;
	}
	
	
	//reflex clock_Hour when:0=0 {write(current_time);}
	
	
	geometry shape <- envelope(bound_shapefile);
	
	
	string pressure_record <- "time,";
	string capacity_record <- "time,";
	parking recording_parking_sample;
	list<parking> list_of_parkings;
	float total_weight_office;
	float total_weight_residential;	
	// INITIALIZATION:
	bool residence_type_randomness;
	init {
		create parking from: parking_footprint_shapefile with: [
			ID::int(read("Parking_id")),
			capacity::(int(read("Capacity"))/multiplication_factor),
			total_capacity::(int(read("Capacity"))/multiplication_factor), 
			excess_time::int(read("time"))
		];
		list_of_parkings <- list(parking);
		

		//create Aalto_buildings from: campus_buildings with: [usage::string(read("Usage")), scale::string(read("Scale")), weight::float(read("Weight"))]{
		//	if usage = "O"{
		//		color <- 	rgb(200,140,0,70);
				
		//	}
		create office from: campus_buildings with: [usage::string(read("Usage")), scale::string(read("Scale")), weight::float(read("Weight"))] {
			if usage != "O"{
				do die;
			}
			color <- #red;
		}
		
		create residential from: campus_buildings with: [usage::string(read("Usage")), scale::string(read("Scale")), weight::float(read("Weight"))] {
			if usage != "R"{
				do die;
			}
			color <- #yellow;
			if weight = 0 {
				weight <- 1.0;
			}
			
			//TODO Here the capacity is not defined in the SHP file, therefore for the sake of demonstration capacity is set to 1
			
			//capacity <- capacity / multiplication_factor;
			capacity <- 1;
		}
		
		create gateways from: gateways_file{
			capacity <- number_of_people;
		}
		
		// ------ ADJUSTING THE WEIGHT OF THE BUILDINGS
		
		total_weight_office <- sum(office collect each.weight);
		total_weight_residential <- sum(residential collect each.weight);
		write(total_weight_office);		
		write(total_weight_residential);
		
		
		
		loop i from:0 to:length(list(office))-1{
			office[i].total_capacity <- int(((office[i].weight * number_of_people)/total_weight_office)/multiplication_factor)+1;
			office[i].capacity <- int(((office[i].weight * number_of_people)/total_weight_office)/multiplication_factor)+1;
		}
		

		
		
	
		
		

		create car_road from: roads_shapefile;
		car_road_graph <- as_edge_graph(car_road);
		
		//USER GROUP CREATION
		
		create aalto_staff number: count_of_staff / multiplication_factor {
			location <- {0,0,0};
			time_to_work <- int((min_work_start_for_staff + rnd(max_work_start_for_staff - min_work_start_for_staff))*60);
			time_to_sleep <-int((min_work_start_for_staff + min_work_duration_for_staff + rnd(max_work_duration_for_staff - min_work_duration_for_staff))*60);
			objective <- "resting";
			people_color_car 	<- rgb(184,213,67)  ;
			people_color		<- rgb(238,147,36)  ;
		}		
		
		create aalto_student number: count_of_students / multiplication_factor {
			location <- {0,0,0};
			time_to_work <- int((min_work_start_for_student + rnd(max_work_start_for_student - min_work_start_for_student))*60);
			time_to_sleep <-int((min_work_start_for_student + min_work_duration_for_student + rnd(max_work_duration_for_student - min_work_duration_for_student))*60);
			objective <- "resting";
			people_color_car 	<- rgb(106,189,69)  ;
			people_color		<- rgb(230,77,61)  ;
		}		
		
		create aalto_visitor number: count_of_visitors / multiplication_factor {
			location <- {0,0,0};
			time_to_work <- int((min_work_start_for_visitor + rnd(max_work_start_for_visitor - min_work_start_for_visitor))*60);
			time_to_sleep <-int((min_work_start_for_visitor + min_work_duration_for_visitor + rnd(max_work_duration_for_visitor - min_work_duration_for_visitor))*60);
			objective <- "resting";
			people_color_car 	<- rgb(31,179,90)  ;
			people_color		<- rgb(151,26,47) ;
		}
		
		do creat_headings_for_csv;


	}

	// DATA RECOD`RDING SECTION:
	
	int day_counter <- 1;
	string pressure_csv_path <- "../results/";
	string capacity_csv_path<- "../results/";
	
	action record_parking_attribute{
		pressure_record <- pressure_record + current_time;
		capacity_record <- capacity_record + current_time;
				
		loop a from: 0 to: length(list_of_parkings)-1	 { 
			recording_parking_sample <-list_of_parkings[a];
			pressure_record <- pressure_record + list_of_parkings[a].pressure *multiplication_factor + "," ;
			capacity_record <- capacity_record + list_of_parkings[a].vacancy *multiplication_factor + "," ;
		}	
		pressure_record <- pressure_record + char(10);
		capacity_record <- capacity_record + char(10);
	}
	
	action creat_headings_for_csv {
		loop b from: 0 to: length(list_of_parkings)-1	 { 
			pressure_record <- pressure_record + list_of_parkings[b].ID + "," ;
			capacity_record <- capacity_record + list_of_parkings[b].ID + "," ;
		}		
		pressure_record <- pressure_record + char(10);
		capacity_record <- capacity_record + char(10);
	}

	reflex save_the_csv when: current_time = 0{
		// TODO: just for testing, it should be removed later
		do pause; 
		
		save string(pressure_record) to: pressure_csv_path + string(#now, 'yyyyMMdd- H-mm - ') + "pressure" + day_counter + ".csv"  type:text ;
		save string(capacity_record) to: pressure_csv_path + string(#now, 'yyyyMMdd- H-mm - ') + "capacity" + day_counter + ".csv"  type:text ;
	}
	reflex time_to_record_stuff when: current_time mod 1 = 0{
		do record_parking_attribute;
	}
	
	// USER INTERACTION SECTION:
	
	map<string,unknown> my_input_capacity; 
	map my_agent_type;
	point target;
	action create_agents 
	{
		target <- #user_location;
		my_agent_type <- user_input("please enter the agent type: [1 = parking, 2 = Residential, 3 = Office]", ["type" :: 1]);

		write(target);
		if my_agent_type at "type" = 1 {
			do create_user_parking(target);
		}
		else if my_agent_type at "type" = 2{
			do create_user_residential(target);
		}
		else if my_agent_type at "type" = 3{
			do create_user_office(target);
		}
		else {
			write("this type of agent does not exist");
		}

	}
	
	action create_user_parking(point target_location){
		my_input_capacity <- user_input("Please specify the parking capacity", "capacity" :: 100);
		create parking number:1 with:(location: target_location) {
			capacity <- int(my_input_capacity at "capacity") ;
			total_capacity <-  int(my_input_capacity at "capacity");
			//vacancy <- (int(my_input_capacity at "capacity")/int(my_input_capacity at "capacity"));
			shape <- square(20);
			color <- #red;
			list_of_parkings <- list(parking);
			write("A parking was created with capacity of "+ char(10) + string(capacity) + char(10) + "and total capacity of " + char(10)+ string(total_capacity));
		}
		
	
	}
	
	action create_user_residential(point target_location){
		my_input_capacity <- user_input("Please specify the count of people living in the building", "capacity" :: 100);
		create residential number:1 with:(location: target_location ) {
			capacity <- int(my_input_capacity at "capacity");
			usage <- "R";
			shape <- polygon([target_location + {-10,-10},target_location + {-10,10},target_location + {10,-10},target_location + {10,10}]);		
			write("A building was constructed and count of dwellers are: " + char(10) + string(capacity));
		}

	}
	
	action create_user_office(point target_location){
		my_input_capacity <- user_input("Please specify the amount of people work at the office", "capacity" :: 100);
		create office number:1 with:(location: target_location) {
			capacity <- int(my_input_capacity at "capacity");
			usage <- "O";
			shape <- polygon([target_location + {-10,-10},target_location + {-10,10},target_location + {10,-10},target_location + {10,10}]);
			write("A building was constructed and count of employees are: " + char(10) + string(capacity));
		}

	}



}




species Aalto_buildings parent:building schedules:[] {
	string usage;
	string scale;
	rgb color <- rgb(150,150,150,20);
	aspect base {
		draw shape color: color empty: true depth:  (total_capacity / 5);
	}
	int capacity;
	int total_capacity;
	float weight;
}

species office parent:Aalto_buildings schedules:[] {
	
}

species residential parent:Aalto_buildings schedules:[] {

	action accept_people {
		capacity <- capacity -1;
	}
	
	action remove_people {
		capacity <- capacity + 1;		
	}
}

species gateways parent:residential schedules:[] {
	aspect base {
		draw circle(50) color: #blue;
	}
}

species parking {
	int capacity;
	int ID;
	int total_capacity;
	int excess_time <- 600;
	int pressure <- 0 ;
	//TODO: This should be fixed, for now it prevents division by zero
	float vacancy <- (capacity/(total_capacity + 0.0001)) update: (capacity/(total_capacity + 0.0001) );
	aspect Envelope {
		draw shape color: rgb(200 , 200 * vacancy, 200 * vacancy) ;
	}
	aspect pressure {
		draw circle(5) depth:pressure * multiplication_factor color: #orange;
	}
	
	reflex reset_the_pressure when: current_hour = max_work_start * 60{
		pressure <- 0 ;
	}
}

species aalto_people parent:people skills: [moving] {
	
	office working_place;
	residential living_place;
	
	bool driving_car;
	bool mode_of_transportation_is_car <- true;
	
	bool could_not_find_parking <- false;
	
	int time_to_work;
	int time_to_sleep;
	
	list<parking> list_of_available_parking;

	point the_target_parking;
	parking chosen_parking;
	string objective;
	
	point the_target <- nil;
	point living_place_location;
	
	rgb people_color_car ;
	rgb people_color	;
	
	// ----- ACTIONS
	action create_list_of_parkings{
		list_of_available_parking <- sort_by(parking where (distance_to(each.location, working_place) < max_walking_distance  ),distance_to(each.location, working_place));
	}
	
	action find_living_place {
		if (sum(residential collect each.capacity)!= 0 and flip(0.5) = true){
			living_place <- one_of(shuffle(residential where (each.capacity > 0)));
			ask living_place {
				do accept_people;
			}
			mode_of_transportation_is_car <- false ;
			driving_car <- false;
		}
		else {
			living_place <- one_of(shuffle(gateways));
			mode_of_transportation_is_car <- true;
			driving_car <- false;
		}
	}
	
	
	action park_the_car(parking target_parking) {
		target_parking.capacity <- target_parking.capacity -1;
	}
	
	action take_the_car(parking target_parking) {
		target_parking.capacity <- target_parking.capacity +1;
	}
	
	
	action distribution_by_weight (Aalto_buildings chosen_working_space) {
		chosen_working_space.capacity <- chosen_working_space.capacity -1 ;
	}
	
	action choose_working_place {
		working_place <- one_of(shuffle(office where (each.capacity > 0)));
		do distribution_by_weight (working_place);
	}
	
	action Choose_parking {
		do create_list_of_parkings;
		chosen_parking <- one_of(list_of_available_parking where (
											(each.capacity 		> 0) and 
											(each.excess_time 	> (time_to_work - time_to_sleep) 
											))
		);
		the_target_parking <- any_location_in(chosen_parking);		
	}
	// ----- REFLEXES 	
	reflex time_to_go_to_work when: current_time = time_to_work and objective = "resting" {
		could_not_find_parking <- false;
		do find_living_place;
		living_place_location <- any_location_in(living_place);
		location <- living_place_location;
		
		
		do choose_working_place;
		
		if (mode_of_transportation_is_car = true) {
			do Choose_parking;
			the_target <- any_location_in(working_place);
			objective <- "working";
		}	
		
		else {
			the_target <- any_location_in(working_place);
			objective <- "working";
		}
	}
	
	reflex time_to_go_home when: current_time = time_to_sleep and objective = "working" {
		objective <- "resting";
		
		the_target <- any_location_in(living_place);
	}
	
	reflex change_mode_of_transportation when: mode_of_transportation_is_car = true and (location = the_target_parking or location = living_place_location) {
// TODO needs re-definition. 
		if location = the_target_parking {
			if chosen_parking.capacity > 0 and objective = "working"{
				driving_car <- false;
				do park_the_car(chosen_parking);
			}
			else if objective = "resting" and driving_car = false{
				driving_car <- true;
				do take_the_car(chosen_parking);
	
			}
			else if (list_of_available_parking collect each.capacity) != 0 {
				chosen_parking.pressure <- chosen_parking.pressure  + 1;
				do Choose_parking;
			}
			else{
				could_not_find_parking <- true;
				target <- any_location_in(living_place);
				objective <- "resting";
				chosen_parking <- nil;
			}
		
		}
		else {
			if objective = "working" {
				driving_car <- true;
			}
			else {
				driving_car <- false;
				target <- nil;
			}
		}

	}
	reflex move when: the_target != nil {
		if (driving_car = true){
			if (objective = "working"){
				do goto target: the_target_parking on: car_road_graph  speed: (1 + rnd(0,5)#km / #h);
			}
			else{
				do goto target: the_target on: car_road_graph speed: (1 + rnd(0,5)#km / #h);
			}
		}
		else {
			if (objective = "working"  ){
				do goto target: the_target on: car_road_graph speed: (0.1 + rnd(0,5) #km / #h);
			}
			else {
				if (mode_of_transportation_is_car = true){
					do goto target: the_target_parking on: car_road_graph speed: (0.1 + rnd(0,5)#km / #h);
				}
				else {
					do goto target: the_target on: car_road_graph speed: (0.1 + rnd(0,5) #km / #h);
				}
			}
		}
		
      	if the_target = location {
        	the_target <- nil ;
		}
	}
	
	
	
	aspect base {
		if driving_car = true {
			draw circle(2) color: people_color_car;
		} else{
			draw square(2) color: people_color;
		}
		
	}
}



// ----------------- USER GROUPS -----------------------


species aalto_staff parent: aalto_people {
	
}

species aalto_student parent: aalto_people {
	
}

species aalto_visitor parent: aalto_people {
	
}

// ----------------- ROADS SPECIES ---------------------

species car_road schedules:[]{
	aspect base{
		draw shape color: rgb(50,50,50) width:2;
	}
}

grid emmision_grid {
	
}


// ----------------- EXPREIMENTS -----------------
experiment parking_pressure type: gui {
	float minimum_cycle_duration <- 0.01;
	output {

		display charts {
			chart "parking occupied (%)" size: {1 , 0.5} type: series{
				datalist list(parking)
				value: list((parking collect ((1-each.vacancy)*100)))
				marker: false
				style: spline;
			} 
			chart "total parking vacancy" size: {1 , 0.5}  position: {0,0.5}type: series{
				data "Total Parking Vacancy (%)"
				value: mean(list(parking) collect each.vacancy)
				marker: false
				style: spline;
				
			} 
		}
		display pie_charts {
			chart "Staff found suitable parking (%)" size:{0.3 , 0.2} position: {0,0.2} type:pie{
				data "Parking found"value: list(aalto_people) count (each.chosen_parking != nil) color:#chartreuse;
				data "Parking Not specified" value: list(aalto_people) count (each.chosen_parking = nil) color:#coral;
				data "Parking Not found" value: list(aalto_people) count (each.could_not_find_parking = true) color:#grey;
			}
			chart "Students found suitable parking (%)" size:{0.3 , 0.2} position: {0,0.4} type:pie{
				data "Parking found"value: list(aalto_people) count (each.chosen_parking != nil) color:#chartreuse;
				data "Parking Not specified" value: list(aalto_people) count (each.chosen_parking = nil) color:#coral;
				data "Parking Not found" value: list(aalto_people) count (each.could_not_find_parking = true) color:#grey;
			}
			chart "Visitors found suitable parking (%)" size:{0.3 , 0.2} position: {0,0.6} type:pie{
				data "Parking found"value: list(aalto_people) count (each.chosen_parking != nil) color:#chartreuse;
				data "Parking Not specified" value: list(aalto_people) count (each.chosen_parking = nil) color:#coral;
				data "Parking Not found" value: list(aalto_people) count (each.could_not_find_parking = true) color:#grey;
			}
			
			chart "Count of parkings with capacity" size:{0.3 , 0.5} position: {0.3,0} type:pie{
				data "Parkings with remaining capacity"value: list(parking) count (each.vacancy != 0) color:#chartreuse;
				data "Parkings with Full capacity"value: list(parking) count (each.vacancy = 0) color:#coral;
			}
			chart "total remaining capacity" size:{0.3 , 0.5} position: {0.6,0} type:pie{
				data "vacant (%)"value: mean(list(parking) collect each.vacancy) color:#chartreuse;
				data "Full (%)"value: 1 - mean(list(parking) collect each.vacancy) color:#coral;
			}
			chart "found suitable parking (%)" size:{1 , 0.5} position: {0,0.5} type:series{
				data "Parking found"value: list(aalto_people where (each.mode_of_transportation_is_car = true)) count (each.chosen_parking != nil and each.could_not_find_parking != true) 
				color:#chartreuse
				marker: false;
			}
		}
		display map_2D_interface type:java2D background: #black{
			species car_road aspect: base ;
			// species pedestrian_road aspect: base ;
			species parking aspect: Envelope ;
			species office aspect:base;
			species residential aspect:base;
			species gateways aspect:base;
			species aalto_staff aspect:base;
			species aalto_student aspect:base;
			species aalto_visitor aspect:base;
			event 'c' action: create_agents;
		}
		display Map_3D type:opengl background: #black{
			species car_road aspect: base ;
			// species pedestrian_road aspect: base ;
			species parking aspect: Envelope ;
			species parking aspect: pressure;
			species office aspect:base;
			species residential aspect:base;
			species aalto_staff aspect:base;
			species aalto_student aspect:base;
			species aalto_visitor aspect:base;
			species gateways aspect:base;
		}
	}
}
