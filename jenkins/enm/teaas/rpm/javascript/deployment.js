var array_tickets=[];

function step_1(){
	
	  var opts = {
			  lines: 8 // The number of lines to draw
			, length: 4 // The length of each line
			, width: 5 // The line thickness
			, radius: 8 // The radius of the inner circle
			, scale: 1 // Scales overall size of the spinner
			, corners: 0.6 // Corner roundness (0..1)
			, color: '#000' // #rgb or #rrggbb or array of colors
			, opacity: 0.25 // Opacity of the lines
			, rotate: 22 // The rotation offset
			, direction: 1 // 1: clockwise, -1: counterclockwise
			, speed: 0.6 // Rounds per second
			, trail: 45 // Afterglow percentage
			, fps: 20 // Frames per second when using setTimeout() as a fallback for CSS
			, zIndex: 2e9 // The z-index (defaults to 2000000000)
			, className: 'spinner' // The CSS class to assign to the spinner
			, top: '50%' // Top position relative to parent
			, left: '50%' // Left position relative to parent
			, shadow: false // Whether to render a shadow
			, hwaccel: false // Whether to use hardware acceleration
			, position: 'absolute' // Element positioning
			}

	$(".spinner").removeClass("hidden");
	var target = document.getElementById('button_step_1')
	var spinner = new Spinner(opts).spin(target);
	
	
	//Rest values
	
    $("#label_step_1").text("");
    $('#select-service-groups').empty();

	deployment_id=$('input[name=deploymentid]:checked').val();
	if(typeof deployment_id === 'undefined' || deployment_id === null || deployment_id == ""){
	  	  $("#label_deployment_id").text("Choose Deployment ID");
	      $("#label_deployment_id").css("color",'red');
	      $(".spinner").addClass("hidden");
	      return;
	}
	else{
		$("#label_deployment_id").text("Deployment ID");
	    $("#label_deployment_id").css("color",'black');
	}
	rpm_url=$("#rpm_url").val();
	
	if(typeof rpm_url === 'undefined' || rpm_url === null || rpm_url == ""){
	  	  $("#label_rpm_url").text("RPM Url");
	      $("#label_rpm_url").css("color",'red');
	      $(".spinner").addClass("hidden");
	      return;
	}
	else{
		$("#label_rpm_url").text("RPM Url");
	    $("#label_rpm_url").css("color",'black');
	}
	
	install_type=$('input[name=install_type]:checked').val();
	if(typeof install_type === 'undefined' || install_type === null || install_type == ""){
	  	  $("#label_install_type").text("Choose RPM Install Type");
	      $("#label_install_type").css("color",'red');
	      $(".spinner").addClass("hidden");
	      return;
	}
	else{
		$("#label_install_type").text("RPM Install Type");
	    $("#label_install_type").css("color",'black');
	    
	    //If install type is model then check rpm for model occurance
	    if( install_type.indexOf('model') != -1 ){
	    	if( rpm_url.indexOf('model') != -1 ){
	    		
	    	}
	    	else{
	    		alert("Are you sure its a model rpm?");

	    	}
	    }
	    if( rpm_url.indexOf('model') != -1 ){
	    	if( install_type.indexOf('model') != -1 ){
	    		
	    		   

	    	}
	    	else{
	    		console.log("Are you sure its a service rpm?");
	    		alert("Are you sure its a service rpm?");
	    	}
	    }
	    	   
	    
	    
	}
	
	
    $("#select-service-groups_div").addClass("hidden");
    $("#select_service_group_options_div").addClass("hidden");
    $("#apply-rpm-button").addClass("hidden");

    

    

	
	//Check Jira ticket is in the list
	var jira_ticket_value=$("#jira-ticket-input").val();
	if(jQuery.inArray(jira_ticket_value, array_tickets) !== -1){
		
	  	  $("#label-jira-ticket").text(jira_ticket_value+" is valid");
	      $("#label-jira-ticket").css("color",'green');
	}
	else{
  	  $("#label-jira-ticket").text("Invalid Jira Ticket Number");
      $("#label-jira-ticket").css("color",'red');
      $(".spinner").addClass("hidden");
		return;
	}
	return jQuery.ajax({  
		  type: 'GET',
		  data:"step=1&deploymentid="+deployment_id+"&rpmurl="+rpm_url,
	      url:  'http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php',
	      success: function(data,status,xhr){
	    	  
	    		$(".spinner").addClass("hidden");
	    		
	    	  console.log("Response from Server "+data);
	    	  var LEVEL;
	    	  var MESSAGE;
	    	  PERMISSION_RESPONSE=$.parseJSON(data);
	    	  jQuery.each(PERMISSION_RESPONSE, function(key,value){
                  if(key=="LEVEL"){
	                  if(value=="SUCCESS")
	                  {
                          LEVEL="success";
                          ICON="fa fa-check-square-o fa-2x";
	
	                  }
	                  else if(value=="WARNING")
	                  {
                          LEVEL="warning";
                          ICON="fa fa fa-times fa-2x";
	                  }
	                  else if(value=="NOTICE")
	                  {
                          LEVEL="info";
                          ICON="fa fa-check-square-o fa-2x";
	                  }
	                  else
	                  {
                          LEVEL="ERROR";
                          ICON="fa fa fa-times fa-2x";
	                  }
                  }
                  else if(key=="MESSAGE"){
                	  
                	  MESSAGE=value;
                	  if(LEVEL=="ERROR"){
                    	  $("#label_step_1").text(MESSAGE);
                          $("#label_step_1").css("color",'red');
                          return;
                	  }
                	  else{
                		  //Retrieve list of Service Groups
            	    	  var list_of_service_groups=MESSAGE.split(" ");
            	    	  $.each(list_of_service_groups,function(i){
            	    		  if(list_of_service_groups[i]!=""){
            				      $("#select-service-groups").append("<option value=\""+list_of_service_groups[i]+"\">"+list_of_service_groups[i]+"</option>");
            				      $("#select-service-groups_div").removeClass("hidden");
            	    		  }

            	    	  });
                	  }
                  }
	    	  });
	    	  
	    	 


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
	    	//console.log()
	    }
	});
	
	return false;
}

function service_group_select(){
	
    $("#select_service_group_options_div").removeClass("hidden");
    $("#apply-rpm-button").removeClass("hidden");
    
    $('#sortable').empty();

    $( "#sortable" ).sortable();
    $( "#sortable" ).disableSelection();
    
	$("#select-service-groups option:selected").each(function()
	{
		var service_group_name=$(this).val();
		$("#select_service_group_options_div").append()
		$("#sortable").append("<font size=\"1\"><li class=\"ui-state-default\"><span class=\"ui-icon ui-icon-arrowthick-2-n-s\"></span>"+service_group_name+"</li></font>");
		
	});

	
}





function get_jira_list(){
	
	
	return jQuery.ajax({  
		  type: 'GET',
		  data:"step=jira",
	      url:  'http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php',
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
							var object = value2;
							var transitionArray=[];
						    for (property in object){

						        var value3 = object[property];
						        //console.log(property + "=" + value3); 
	
						        
						        if(property=="key"){
							        //console.log(property + "=" + value3); 
							        ticket_id=value3;	
							        //console.log(ticket_id);
							        array_tickets.push(ticket_id);
	                            }
						        
						    }
						});
					}
				});
			}
			catch( e){
				console.log(e);
			}
			
			$( "#jira-ticket-input" ).autocomplete({
			      source: array_tickets
			});
			$("#jira-ticket-input").removeAttr('disabled');

	    }
	});
	
	
						    
}
function install_rpm(){
	
	$("#label_install_rpm").text("Click");
    $("#label_install_rpm").css("color",'black');

	install_type=$('input[name=install_type]:checked').val();
	deployment_id=$('input[name=deploymentid]:checked').val();
	rpm_url=$("#rpm_url").val();
	jira_ticket=$("#jira-ticket-input").val();
	var service_groups_ordered="";
	
	var count=0;
	$("#select_service_group_options_div").find("li").each(function() {
		if(count!=0){
			service_groups_ordered=service_groups_ordered+","+$(this).text();

		}
		else{
			service_groups_ordered=$(this).text();

		}
		count++;
	});
	
	
	return jQuery.ajax({  
		  type: 'GET',
		  data:"step=2&deploymentid="+deployment_id+"&rpmurl="+rpm_url+"&jira_ticket="+jira_ticket+"&install_type="+install_type+"&service_groups="+service_groups_ordered,
	      url:  'http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php',
	      success: function(data,status,xhr){
	    	  
	    		$(".spinner").addClass("hidden");
	    		
	    	  console.log("Response from Server "+data);
	    	  var LEVEL;
	    	  var MESSAGE;
	    	  PERMISSION_RESPONSE=$.parseJSON(data);
	    	  jQuery.each(PERMISSION_RESPONSE, function(key,value){
                if(key=="LEVEL"){
	                  if(value=="SUCCESS")
	                  {
                        LEVEL="SUCCESS";
                        ICON="fa fa-check-square-o fa-2x";
	
	                  }
	                  else if(value=="WARNING")
	                  {
                        LEVEL="WARNING";
                        ICON="fa fa fa-times fa-2x";
	                  }
	                  else if(value=="NOTICE")
	                  {
                        LEVEL="NOTICE";
                        ICON="fa fa-check-square-o fa-2x";
	                  }
	                  else
	                  {
                        LEVEL="ERROR";
                        ICON="fa fa fa-times fa-2x";
	                  }
                }
                else if(key=="MESSAGE"){
              	  
              	  MESSAGE=value;
              	  if(LEVEL=="ERROR"){
                  	  $("#label_install_rpm").text(MESSAGE);
                        $("#label_install_rpm").css("color",'red');
                        return;
              	  }
              	  if(LEVEL=="SUCCESS"){
                	  $("#label_install_rpm").text(MESSAGE);
                      $("#label_install_rpm").css("color",'green');
                      //Trigger tab click
                      $('#tabs a[href="#tabs-2"]').trigger('click');
                      deployment_id=$('input[name=deploymentid]:checked').val();
                      $("#logs_select_deployment").val(deployment_id);
                      datatables();
                      
                      
                      return;
            	  }
                }
	    	  });
	    	  
	    	 


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
	    	//console.log()
	    }
	});
	
	return false;
	
	
	
}