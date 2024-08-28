var current_calendar_view="IN_TESTING";
function load_calendar(){

	var title,ticket_url;
	
        $('#calendar').fullCalendar({

            eventRender: function(event, element){
            	
            	try{
	                var tmp=element[0].innerText;
            		//console.log("tmp:"+tmp);

	                var split_array = tmp.split('12a');
	                var text=split_array[1];
                    if( typeof text === 'undefined' || text === null || text == ""){
                    	
                    	text=tmp;
                    }
	                
	                var split_array2 = text.split('::');
	                title=split_array2[0];
	
	                var split_array3 = text.split('::');
	                ticket_url=split_array2[1];

            	}
            	catch(e){
            		console.log("Catch:"+e);
            	}
                element.html(title);
                /*
           	 	element.qtip({
                    content: {
                   	 text: "<a href='"+ticket_url+"'>"+ticket_url+"</a>"
                    },

                    
                });*/	
               
            },
            eventClick: function(calEvent, jsEvent, view) {

            	
            	var tmp=calEvent.title;
                var split_array = tmp.split('::');
                var url=split_array[1];
                
                //alert('Event: ' + url);
                //window.open(url, '_blank');
                //return false;
                //alert('Coordinates: ' + jsEvent.pageX + ',' + jsEvent.pageY);
               // alert('View: ' + view.name);

                // change the border color just for fun
                //$(this).css('border-color', 'red');

            	/*
            	 * Remove old pop ups
            	 */

                jQuery(".notifyjs-warning2-base").remove();
                
                $.notify.addStyle('warning2', {
                	  html: "<div id=\"my_id_for_funny_notify\"><span data-notify-html/></div>",//data-notify-text -- template
                	  classes: {
                	    base: {
                	      "white-space": "nowrap",
                	      "background-color": "white",
                	      "padding": "10px",
                	      "color": "black"
                	    },
                	    superblue: {
                	      "color": "white",
                	      "background-color": "blue"
                	    }
                	  }
                	});
                
            	$.notify("<a target='_blank' href='"+url+"'>Open In Jira</a>",{
			        position:"bottom center",
			        clickToHide: true,
			        autoHide: true,
			        autoHideDelay: 600000,
			        style: 'warning2'
			    });
            	
            	
            },
            eventMouseover: function(event, jsEvent, view) {
            	
            	$(this).removeClass("alert-sucess");
            	$(this).addClass("alert-success-border");

            	

            },
            eventMouseout: function (event) {
            	
            	$(this).addClass("alert-sucess");
            	$(this).removeClass("alert-success-border");

            }
           
        });
        
        $('.fc-prev-button').click(function(){
        	   //alert('prev is clicked, do something'+current_calendar_view);
        	   ajax_jira_call(current_calendar_view);
        	});

        	$('.fc-next-button').click(function(){
        	   //alert('nextis clicked, do something'+current_calendar_view);
        	   ajax_jira_call(current_calendar_view)
        });
   
}

function ajax_jira_call(filter){
	
	/*
	 * Reset calendar
	 */
	
	current_calendar_view=filter;
    var myCalendar = $('#calendar'); 
	myCalendar.fullCalendar( 'removeEvents' );
	
	//$("#ticket-alert").html("No planned start/end dates set for: ");
	

	
	$("#spinner_progress").addClass("fa-spin");
	$("#spinner_progress").removeClass("hidden");

	return jQuery.ajax({  
		  type: 'GET',
		  data:"filter="+filter,
	      url:  'http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/calendar/login.php',
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
	    	
	    	try
	    	{
	    		var parse_json=$.parseJSON(JSON_RESPONSE);
	    	}
	    	catch (e){
	    		/*
	    		 * Jira Query Failed for some reason
	    		 */
	    		 $.notify("No Tickets Retrieved",{
					        position:"top right",
					        clickToHide: true,
					        autoHide: true,
					        autoHideDelay: 6000,
					});    		 
	    	}

			
			
			try{
				
				var count=0;
				jQuery.each(parse_json, function(key,value){
	

					
					
					if(key=="issues"){

						jQuery.each(value, function(key2,value2){

							//console.log("Count:"+count);
							//count++;
							
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
			                var typeOfAccess;
			                var fontColour;
			                var ticketStatus;
			                var created;
							var object = value2;
							var transitionArray=[];
						    for (property in object){

						        var value3 = object[property];
						        //console.log(property + "=" + value3); 
	
						        
						        if(property=="key"){
							        //console.log(property + "=" + value3); 
							        ticket_id=value3;						       
	                            }
						        
						        if(property=="changelog"){
						        	
						        	transitionArray=getStartEndDatesArray(value3,"Testing");
						        }
						        if(property=="fields"){
						        	
						        
						        	
						        	for (property2 in value3){
								        var value4 = value3[property2];
								       
								        //console.log("Field Name:"+property2 + "=" + value4); 
								        if(property2=="summary")
								        {
								        	summary=$.trim(value4);
	                                    }
								        if(property2=="created")
								        {
								        	created=$.trim(value4);
	                                    }
								        if(property2=="environment")
								        {
								        	environment=$.trim(value4);
	                                    }
	                                    if(property2=="customfield_25008"){
	                                        //planned_start_date=$.trim(value4);
	                                        
	                                        tmp_planned_start_date=$.trim(value4);
	                                        if( typeof tmp_planned_start_date === 'undefined' || tmp_planned_start_date === null || tmp_planned_start_date == ""){
	                                        	
	                                        }
	                                        else{
	                                        
		                                        var date = new Date(tmp_planned_start_date); // some mock date
		                                       
		                                        var planned_start_date_milliseconds=date.setDate(date.getDate());
		                                        
		                                        var dateObj = new Date(planned_start_date_milliseconds);
		                                        var day = dateObj.getUTCDate(); //months from 1-12
		                                        if (day<=9){
		                                        	day="0"+day;
		                                        }

		                                        var month = dateObj.getMonth() + 1;
		                                        if (month<=9){
		                                        	month="0"+month;
		                                        }
		                                        var year = dateObj.getUTCFullYear();
		
		                                        newdate=year+"-"+month+"-"+day;
		                                        planned_start_date=newdate;

	                                        }                                     
	                                        
	                                        
	                                    }
	                                    //if(property2=="customfield_25009"){
	                                    //	planned_end_date=$.trim(value4);
	                                    //}
	                                    
	                                     //Commented out due to issue with getMonth not returning preceeding 0 on months 0 to 9
	                                    if(property2=="customfield_25009"){
	                                    	
	                                        tmp_planned_end_date=$.trim(value4);
	                                        if( typeof tmp_planned_end_date === 'undefined' || tmp_planned_end_date === null || tmp_planned_end_date == ""){
	                                        	
	                                        }
	                                        else{
	                                        
		                                        var date = new Date(tmp_planned_end_date); // some mock date
		                                       
		                                        var planned_end_date_milliseconds=date.setDate(date.getDate() + 1);
		                                        
		                                        var dateObj = new Date(planned_end_date_milliseconds);
		                                        var month = dateObj.getMonth() + 1; //months from 1-12
		                                        if (month<=9){
		                                        	month="0"+month;
		                                        }
		                                        var day = dateObj.getUTCDate();
		                                        if (day<=9){
		                                        	day="0"+day;
		                                        }
		                                        var year = dateObj.getUTCFullYear();
		
		                                        newdate=year+"-"+month+"-"+day;
		                                        planned_end_date=newdate;
	                                        }                                     
	                                    }
	                                    
	
								        if(property2=="creator")
								        {
								        	for (creator in value4) {
								        		var value5 = value4[creator];
								        		
								        		
								        		if(creator=="displayName"){
								        			reporter=$.trim(value5);
								        		}
								        		else if(creator=="key"){
								        			eid=$.trim(value5);
								        		}
								        		else if(creator=="emailAddress"){
								        			emailAddress=$.trim(value5);
								        		}
								        	}
	
								        }
								        if(property2=="customfield_25604")
								        {
								        	
								        	for (accessType in value4) {
								        		var value6 = value4[accessType];
								        		
								        		
								        		if(accessType=="value"){
								        			typeOfAccess=$.trim(value6);
								        		}
								        		
								        	}
	
								        }
								        if(property2=="assignee")
								        {
								        	for (assigneeOptions in value4) {
								        		var value7 = value4[assigneeOptions];
								        		
								        		
								        		if(assigneeOptions=="displayName"){
								        			assignee=$.trim(value7);
								        		}
								        		
								        	}
	
								        }
								        
								        if(property2=="status")
								        {
								        	for (statusOptions in value4) {
								        		var value8 = value4[statusOptions];
								        		
								        		
								        		if(statusOptions=="name"){
								        			ticketStatus=$.trim(value8);
								        		}
								        		
								        	}
	
								        }
								    }
						        	
						        }
						    }
						    
							if( typeof planned_end_date === 'undefined' || planned_end_date === null || planned_end_date == ""){
	
								if(ticketStatus=="Testing"){
									//$("#ticket-alert").append("<br><b>"+ticket_id+": "+assignee);
									
								    $.notify("Dates not set: "+ticket_id+" - "+assignee,{
								        position:"top right",
								        clickToHide: true,
								        autoHide: true,
								        autoHideDelay: 6000,
								    });

								}
			                    
			                    
	
			                }
							else if(ticketStatus!=filter &&filter !="EXCLUSIVE"){
								//Skip ticket
								console.log("ticketStatus:"+ticketStatus+" Filter:"+filter);
								//console.log("Ignoring Tcket:"+ticket_id);
							}
			                else
			                {
			                	//console.log("Ticket Number: "+ticket_id+" Planned start date:"+planned_start_date+" Planned end date:"+planned_end_date);
	
			                	className="";
			                	//console.log("Status:"+ticket_id+" : "+ticketStatus);
			                	if(ticketStatus=="Testing"){
				                	className="alert-success";
				                	
			                	}
			                	else if(ticketStatus=="Open"){
			                		className="alert-warning";

			                	}
			                	else if(ticketStatus=="Closed"){
			                		className="alert-grey";

			                	}
			                	else if(ticketStatus=="In Progress"){
			                		className="alert-info";

			                	}
			                	else if(ticketStatus=="On Hold"){
			                		className="alert-danger";

			                	}
			                	
	
			                	//console.log("Access Type:"+typeOfAccess);
			                	
			                	if( typeof typeOfAccess === 'undefined' || typeOfAccess === null || typeOfAccess == ""){
			                		fontColour="#000000";
			                		typeOfAccess="Not Set";
			                		
			                	}
			                	else if(typeOfAccess=="Shared"){
			                		fontColour="#067803";
			                	}
			                	else if(typeOfAccess=="Exclusive"){
			                		fontColour="#FF0000";
			                	}
			                	
			                	
				                var split_ticket_id = ticket_id.split('-');
				                var event_id=split_ticket_id[1];
				                
				                
			                	//console.log("Ticket:"+ticket_id+" Env:"+environment+": planned_start_date:"+planned_start_date+" - "+planned_end_date);
			                	var ticket_url="https://jira-nam.lmera.ericsson.se/browse/"+ticket_id;

			                	/*
			                	 * Code to plot tickets with transitions
			                	 */
			                	if (transitionArray[0] != null)
			                	{
			                		jQuery.each(transitionArray, function(key,value){
			                			
			                			var obj=$.parseJSON(value);
			                			orig_planned_start_date=planned_start_date;
			                			planned_start_date=obj.start_date;
			                			

			                			
			                			if(obj.end_date!="NA"){
			                				
			                					planned_end_date=obj.end_date;
			                			}
			                			//console.log(ticket_id+":OPSD:"+orig_planned_start_date+"-start_date:"+planned_start_date+"-end_date:"+planned_end_date);

			                			
			                			var myCalendar = $('#calendar'); 
								        myCalendar.fullCalendar();
								        var myEvent = {
								          id:event_id,
								          title:"<div class='access-type-div pull-right'>Access Type:<font color='"+fontColour+"'><b>"+typeOfAccess+"</b></font></div> <font size='3'><b>"+environment+"</b></font> [ "+ticket_id+" ] - <font class='summary-font' >Summary:<b>"+summary+"</font></b><br><font class='reporter-assignee-font'> Reporter:<b>"+reporter+"</b><br>Asginee:<b>"+assignee+"</b></font><div  class='status-div pull-right'>Status:<font color='"+fontColour+"'><b>"+ticketStatus+"</b></font></div>::"+ticket_url,
					    		          start: planned_start_date,
					                      end: planned_end_date,
					                      className: className
								        };
					                	if(IsNumeric(filter)){
								        	
								        	if(environment == filter){
									            myCalendar.fullCalendar( 'renderEvent', myEvent );
								        	}
								        }
								        else if(filter == "EXCLUSIVE"){
								        	
								        	if(typeOfAccess=="Exclusive"){
									            myCalendar.fullCalendar( 'renderEvent', myEvent );

								        	}
								        }
								        else if(filter != "EXCLUSIVE"){
								        	
								            myCalendar.fullCalendar( 'renderEvent', myEvent );

								        }

			                			
			                		});

							      
			                	}
			                	else{
			                		var myCalendar = $('#calendar'); 
							        myCalendar.fullCalendar();
							        var myEvent = {
							          id:event_id,
							          title:"<div class='access-type-div pull-right'>Access Type:<font color='"+fontColour+"'><b>"+typeOfAccess+"</b></font></div> <font size='3'><b>"+environment+"</b></font> [ "+ticket_id+" ] - <font class='summary-font' >Summary:<b>"+summary+"</font></b><br><font class='reporter-assignee-font'> Reporter:<b>"+reporter+"</b><br>Asginee:<b>"+assignee+"</b></font><div  class='status-div pull-right'>Status:<font color='"+fontColour+"'><b>"+ticketStatus+"</b></font></div>::"+ticket_url,
				    		          start: planned_start_date,
				                      end: planned_end_date,
				                      className: className
							        };
							        
				                	if(IsNumeric(filter)){
							        	
							        	//console.log(environment);
							        	if(environment == filter){
								            myCalendar.fullCalendar( 'renderEvent', myEvent );
							        	}
							        }
							        else if(filter == "EXCLUSIVE"){
							        	
							        	if(typeOfAccess=="Exclusive"){
								            myCalendar.fullCalendar( 'renderEvent', myEvent );

							        	}
							        }
							        else if(filter != "EXCLUSIVE"){
							        	
							            myCalendar.fullCalendar( 'renderEvent', myEvent );

							        }
			                	
			                	}
					        
			                }	
						});
					}
				});	
				applyCheckboxFilters();
				$("#spinner_progress").removeClass("fa-spin");
				$("#spinner_progress").addClass("hidden");


			}
			catch(e){
				console.log(e);
				$("#spinner_progress").removeClass("fa-spin");

			}
	    }
	});  
	
}

function getStartEndDatesArray(changelog,filter){
	
	var tmpCreatedDate;
	var tmpFromState;
	var tmpToState;
	var transitionArray=[];
	var tmpId=0;
	//console.log("In changelog:");

	/*
	 * Get all the Transitions from the tickets history
	 */
	for (property in changelog) {
        //var value4 = changelog[property];
		if(property=="histories"){
			
			var historiesArrays = changelog[property];
			
			for (historiesProperty in historiesArrays){
				var itemsArrays= historiesArrays[historiesProperty];
				for(itemsProperty in itemsArrays){
					
					if(itemsProperty=="created"){
						
						var splitdate=itemsArrays[itemsProperty];
						var tmpCreatedDate=splitdate.split("T",1);
						//console.log("tmpCreatedDate:"+tmpCreatedDate);
						//console(createdDate);
					}
					if(itemsProperty=="items"){
						var itemsContents=itemsArrays[itemsProperty];
						for(items in itemsContents){
							var item = itemsContents[items];
							//console.log("######");
							$.each(item, function(key, value) {
							    if(value=="status"){
							    	tmpId++;
							    	$.each(item, function(keyFound, valueFound){
							    		if(keyFound=="fromString"){
							    			tmpFromState=valueFound;
							    		}
							    		if(keyFound=="toString"){
							    			tmpToState=valueFound;
							    		}
							    		
							    	});
							    	//var entry="{id:\""+tmpId+"\",date:\""+tmpCreatedDate+"\",from-state:\""+tmpFromState+"\",to-state:\""+tmpToState+"\"}";
							    	var entry="{\"id\":\""+tmpId+"\",\"date\":\""+tmpCreatedDate+"\",\"fromState\":\""+tmpFromState+"\",\"toState\":\""+tmpToState+"\"}";
							    	//console.log(entry);
							    	try{
							    			transitionArray.push(entry);
							    			console.log()
							    	}
							    	catch(e){
							    		console.log("Exception:"+e);
							    	}
							    }
							});							
						}
					}
				}
			}
		}
	}

	/*
	 * Create array of In Testing slots 
	 */
	var eventsArray=[];
	var event="";
	var start_date="";
	var end_date="";
	var json="";
	var count=0;
	
	var transitionArrayLength=transitionArray.length;

	jQuery.each(transitionArray, function(key,value){
		count++;
		//console.log(key+" - "+value);
		var obj=$.parseJSON(value);
		//console.log("Date:"+obj.date+" From State:"+obj.fromState+"  - To  State:"+obj.toState);
		
		date=obj.date;
		/*
		 * 	Check for in testing and planned end date
		 */
		if(count==transitionArrayLength){

			//event="{\"start_date\":\""+start_date+"\",\"end_date\":\""+end_date+"\"}";
			//console.log("Event:"+event);
			end_date="NA";
		}
		
		if(obj.toState == filter){
			start_date=obj.date;
		}
		if(obj.fromState == filter){
			end_date=obj.date;
		}
		if(date!="" && start_date!="" && end_date!="" ){
			
			event="{\"start_date\":\""+start_date+"\",\"end_date\":\""+end_date+"\"}";
			//console.log("Event:"+event);
			eventsArray=[];
			eventsArray.push(event);
			json="";
			start_date="";
			end_date="";
			event="";
			//console.log("Date:"+date+" fromState:"+obj.fromState+":toState "+obj.toState);
			//console.log("start_date:"+start_date+" end_date:"+end_date);
		}
		
		
	});
	return eventsArray;
	
}



function IsNumeric(val) {
    return Number(parseFloat(val))==val;
}


function applyCheckboxFilters(){
	
	if($("#status-access-type-checkbox").is(':checked')){
		
		/*
		 * Show access type and status from the view
		 */
		$(".status-div").removeClass("hidden");
		$(".access-type-div").removeClass("hidden");
		
		
	}
	else{
		
		/*
		 * Hide access type and status from the view
		 */
		$(".status-div").addClass("hidden");
		$(".access-type-div").addClass("hidden");

		
	}
	if($("#summary-checkbox").is(':checked')){
		
		$(".summary-font").removeClass("hidden");

	}
	else{
		$(".summary-font").addClass("hidden");

	}
	if($("#reporter-assignee-checkbox").is(':checked')){
		
		$(".reporter-assignee-font").removeClass("hidden");

	}
	else{
		$(".reporter-assignee-font").addClass("hidden");

	}
	
}


