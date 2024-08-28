function load_calendar(){

        $('#calendar').fullCalendar({
            events: [
                {
                	//https://fullcalendar.io/docs/event_data/Event_Object/
                    title: 'CIP-1146',
                    start: '2016-12-20',
                    end: '2016-12-24',
                    url: 'http://www.google.ie',
                    className: 'alert alert-info'

                },
                {
                	//https://fullcalendar.io/docs/event_data/Event_Object/
                    title: 'CIP-1182',
                    start: '2016-12-20',
                    end: '2016-12-24',
                    url: 'http://www.google.ie',
                    className: 'alert alert-danger'

                }
            ],
            eventRender: function(event, element) {
            	
                var title=element[0].innerText;
                element.html(title);
            	 element.qtip({
                     content: "<b>"+title+"</b><div class='alert alert-success'>Title:60K server PM</div><div class='alert alert-success'>Reporter:Jeorme Sheerin <br> Assignee: Some Fella</div>"
                 });
               //var title=element[0].innerText;
               //element.html("<b>"+title+"</b><div class='alert alert-success'>Title:60K server PM</div><div class='alert alert-success'>Reporter:Jeorme Sheerin <br> Assignee: Some Fella</div>");
               
               
            },
            eventClick: function(calEvent, jsEvent, view) {

            	
                //alert('Event: ' + calEvent.title);
                //return false;
                //alert('Coordinates: ' + jsEvent.pageX + ',' + jsEvent.pageY);
               // alert('View: ' + view.name);

                // change the border color just for fun
                //$(this).css('border-color', 'red');

            }
        });
   
}

function ajax_jira_call(){
	
    var myCalendar = $('#calendar'); 
	myCalendar.fullCalendar( 'removeEvents' );
	
	return jQuery.ajax({  
		  type: 'GET',
	      url:  'http://atrclin3.athtem.eei.ericsson.se/calendar/login.php',
	      success: function(data,status,xhr){
	    	  
	      //console.log("Response from Server "+data);

	      try{
	    	  JSON_RESPONSE=data;
	    	  var reponse_code=xhr.status;
	    	  if (reponse_code="200"){
	    		  	   

	    	  }
	    	  else if(reponse_code="404"){
	    		
	    		  console.log("404")
	    	  }
	    	  else if(reponse_code="500") {
		    		
	    		  console.log("500")

	    	  } 
	      	}//try
	      	catch(e){
	    		  console.log("Error:"+e)

	    	}//catch
	      },
	      error: function(xhr, status, error){
	    	
    		  console.log("ERROR")

	    }, 
	    complete: function(data){
	    	
			var parse_json=$.parseJSON(JSON_RESPONSE);
//			var forum = parse_json.issues;
//			
//			for (var i = 0; i < forum.length; i++) {
//			    var object = forum[i];
//			    for (property in object) {
//			        var value = object[property];
//			        console.log(property + "=" + value); // This alerts "id=1", "created=2010-03-19", etc..
//			    }
//			}
			
			
			jQuery.each(parse_json, function(key,value){

				
				
				
				if(key=="issues"){
					jQuery.each(value, function(key2,value2){
						
						//console.log("Key2:"+key2+" value2:"+value2);
						var ticket_id;
						var summary;
						var assignee;
						var reporter;
						var eid;
						var emailAddress;
		                var planned_start_date;
		                var planned_end_date;
		                var environment;
						
						var object = value2;
					    for (property in object) {
					        var value3 = object[property];
					        //console.log(property + "=" + value3); 

					        
					        if(property=="key"){
						        console.log(property + "=" + value3); 
						        ticket_id=value3;
						        
						       
                            }
					        
					        
					        if(property=="fields"){
					        	
					        	
					        	
					        	for (property2 in value3) {
							        var value4 = value3[property2];
							       
							        //console.log("Field Name:"+property2 + "=" + value4); 
							        if(property2=="summary")
							        {
							        	summary=value4;
                                    }
							        if(property2=="environment")
							        {
							        	environment=value4;
                                    }
                                    if(property2=="customfield_25008"){
                                        planned_start_date=value4;
                                    }
                                    if(property2=="customfield_25009"){
                                    	
                                        tmp_planned_end_date=value4;
                                        if( typeof tmp_planned_end_date === 'undefined' || tmp_planned_end_date === null || tmp_planned_end_date == ""){
                                        	
                                        }
                                        else{
                                        
	                                        var date = new Date(tmp_planned_end_date); // some mock date
	                                       
	                                        var planned_end_date_milliseconds=date.setDate(date.getDate() + 1);
	                                        //console.log(planned_end_date_milliseconds);
	                                        
	                                        var dateObj = new Date(planned_end_date_milliseconds);
	                                        var month = dateObj.getUTCMonth() + 1; //months from 1-12
	                                        var day = dateObj.getUTCDate();
	                                        var year = dateObj.getUTCFullYear();
	
	                                        newdate = year + "/" + month + "/" + day;
	                                        planned_end_date=newdate;
                                        }
                                        	
                                       
                                    }

							        if(property2=="creator")
							        {
							        	for (creator in value4) {
							        		var value5 = value4[creator];
							        		
							        		//console.log("Value in Creator:"+creator+" "+value5);
							        		
							        		if(creator=="displayName"){
							        			reporter=value5;
							        		}
							        		else if(creator=="key"){
							        			eid=value5;
							        		}
							        		else if(creator=="emailAddress"){
							        			emailAddress=value5;
							        		}
							        	}

							        }
							    }
					        	
					        }
					    }
					    
						if( typeof planned_end_date === 'undefined' || planned_end_date === null || planned_end_date == ""){

		                    console.log("No planned dates set for "+ticket_id);

		                }
		                else
		                {
		                	console.log("Ticket Number: "+ticket_id+" Planned start date:"+planned_start_date+" Planned end date:"+planned_end_date);

		                    var myCalendar = $('#calendar'); 
					        myCalendar.fullCalendar();
					        var myEvent = {
					          title:ticket_id+" "+reporter+" "+eid+" "+environment,
		    		          start: planned_start_date,
		                      end: planned_end_date,
		                      className: 'alert alert-info'
				            };
				            myCalendar.fullCalendar( 'renderEvent', myEvent );
		                }
						
					});
					

				}
					

				
				
			});	
	    }
	});  
	
}
