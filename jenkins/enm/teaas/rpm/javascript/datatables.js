

function datatables(){
	
	TABLE_ID="DATA_TABLES_TICKETS";
	var deployment_id=$("#logs_select_deployment").val();
	if(deployment_id == ""){
		
		$("#message_installation_logs").addClass("alert alert-danger");
		$("#message_installation_logs").text("Deployment Id has not been selected");
	}
	else{
		$("#message_installation_logs").removeClass("alert alert-danger");
		$("#message_installation_logs").text("");
	}
	
	 if ($.fn.dataTable.isDataTable( '#'+TABLE_ID ) ) {
		    table = $('#'+TABLE_ID).DataTable();
		    table.destroy();
	 	 
	 }
	  
	 
		try{
			
			
			//jQuery("#"+TABLE_ID).parent().removeClass("hidden");
	
			var total_records=0;
	        var table = jQuery('#'+TABLE_ID).DataTable( {
	        	"oLanguage": {
	                "sLoadingRecords": "...",
	                
	        	},
	        	autoWidth: false,
	        	"order": [[ 7, "desc" ]],
	        	"language": {
	                "infoEmpty": "No records available ",
	            },
	            "columnDefs": [
	        	               {   "targets": 	[0],
	        	                   "visible": true,
	        	                   "class": "details-control",
	        	                   "searchable": false,
	        	               }
	        	               ],
               columns : [
                          { width : '50px' },
                          { width : '50px' },
                          { width : '50px' },
                          { width : '100px' },
                          { width : '50px' },        
                          { width : '50px' },
                          { width : '50px' },
                          { width : '50px' },
                          { width : '50px' },
                          { width : '50px' }        
                      ], 
	            "aLengthMenu": [[10, 25, 50, -1], [10, 20, 25, 50, "All"]],
	            "paging":   true,
	            "bSortClasses": false,
	            "ajax": {
	                "url": "http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php?step=populate_datatable",
	                "data": function ( d ) {
	                    d.deployment_id = deployment_id;
	                    //d.pid = "";
	                },
	                error: function (xhr, error, thrown) {
	                		console.log("HERE"+thrown);
	                },
	            },
	            
	            //"fnRowCallback": function( nRow, aData, iDisplayIndex, iDisplayIndexFull ) {
	            "initComplete": function(settings, json) {
	                console.log("Finished Loading...");
	                
	                var oTable = $('#'+TABLE_ID).dataTable();
	                var oSettings = oTable.fnSettings();
	                total_records=oSettings.fnRecordsTotal();
	                var DATA="";
	                
	                var obj= table.ajax.json();
	               
	
	             	console.log("Rows "+total_records);
	             	
	             	//Format Date
	             	CONVERT_TIME_STAMP_TO_DATE(TABLE_ID);
	             	
	             	
		          	  
	          	  jQuery("#"+TABLE_ID).find('tr').each(function() {
	          		  	
	          		  var count=0;
	          		  var id
	          		  jQuery(this).find('td').each(function() {
	          			  
	          			  //get id
	          			  if(count==0){
	          				id=jQuery(this).text();
	          			  }
	          			  	td_contents=jQuery(this).text();

	          			  	// Shorten RPM url 
	          				 if ( td_contents.indexOf("http") != -1){
	          					 var rpm_name="";
	          					td_contents.split("/").forEach(function(myString) {
	          						rpm_name=myString
	          					});
	          					jQuery(this).text(rpm_name);
	          				 }
	          				 	          				 
	          				 //service groups
	          				 count_sg=0;
	          				if ( td_contents.indexOf(",") != -1){
	          					 var rpm_name="";
	          					td_contents.split(",").forEach(function(myString) {
	          						console.log(myString);
	          						if(count_sg==0){
	          							rpm_name=myString;
	          						}
	          						else{
	          							rpm_name=rpm_name+"<br>"+myString;
	          						}
	          						
	          						count_sg++;
	          					});
	          					jQuery(this).html(rpm_name);
	          				}

	          				 
	          				 // END shorten
	          				 
	          				 // Apply monitor/restart button
	          				 
	          				 if(count == 9){
	          					 jQuery(this).html('<i onclick=\'timer_monitor_logs("'+id+'");\' class="fa fa-television fa-lg" aria-hidden="true"></i></i> | <i onclick=\'rollback_orignal_rpm("'+id+'","'+deployment_id+'");\' class="fa fa-trash fa-lg" aria-hidden="true"></i>');
	          				 }
	          			count++;	 
	          		  });
		          		  
		          		  	 
		          			 
		          		});

	              },
	              
	        });
		}
		catch(e){
			console.log("Datatable Error: "+e);
		}
	
		if (total_records == 0) {
	 		
	 	    console.log("No Tickets recieved");
		    
	 	}
		
		 // Array to track the ids of the details displayed rows
	    var detailRows = [];
	    $('#'+TABLE_ID+' tbody').on( 'click', 'tr td.details-control', function () {
	        var tr = $(this).closest('tr');
	        var row = table.row( tr );
	        var idx = $.inArray( tr.attr('uid'), detailRows );
	 
	        if ( row.child.isShown() ) {
	            tr.removeClass( 'details' );
	            row.child.hide();
	 
	            // Remove from the 'open' array
	            detailRows.splice( idx, 1 );
	        }
	        else {
	            tr.addClass( 'details' );
	            
	            var count=0;
	            var row_uid;
	            jQuery(tr).find('td').each(function() {
	            	
	            	if(count==0){
	            		console.log("value:"+$(this).text());
	            		row_id=$(this).text();
	            		count++;
	            	}
	            });
	            console.log("Getting logs");
	            fetch_log_message_ajax( row,row_id,"http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php" );
	            //row.child( format( row.data(),AJAX_URL ) ).show();
	
	            // Add to the 'open' array
	            if ( idx === -1 ) {
	                detailRows.push( tr.attr('uid') );
	            }
	        }
	    } );
	 
	    // On each draw, loop over the `detailRows` array and show any child rows
	    
	    
	    table.on( 'draw', function () {
	        $.each( detailRows, function ( i, id ) {
	            $('#'+id+' td.details-control').trigger( 'click' );
	            
	        } );
	    } );
	
}

function fetch_log_message_ajax (row,id,AJAX_URL) {
	
	
	
	/*
	 * Ajax lookup of uid to get message
	 */
	
	jQuery.ajax({  
		  type: 'POST',
	      url:  AJAX_URL,
	      data: "get_detailed_logs="+id,
	      success: function(data,status,xhr){
	    	  
	      console.log("Response from Server "+data);

	      try{
	    	  JSON_RESPONSE=data;
	    	  var reponse_code=xhr.status;
	    	  if (reponse_code="200"){
	    		  	   
	    	  }
	    	  else if(reponse_code="404"){
	    		
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404");
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
	    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
	    	  }
	    	  else if(reponse_code="500") {
		    		
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 500 ");
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
	    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
	    	  } 
	      	}//try
	      	catch(e){
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Fatal Catch Error "+e);
	    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
	    	}//catch
	      },
	      error: function(xhr, status, error){
	    	
	    	jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404 ");
	  		jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
	  		jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
	    }, 
	    complete: function(data){

			var json =$.parseJSON(JSON_RESPONSE);

	        $.each(json, function(key, value) {
	        	
	        	
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
					else{
						LEVEL="danger";
						ICON="fa fa fa-times fa-2x";
					}
				}
				else if(key=="MESSAGE"){
					
		            row.child( atob(value)).show();
		        	//$('#logs_monitoring_div').html(atob(value));
				}
				
	        });
	    }
	}); 
	  
}
var tid;

function timer_monitor_logs(id){
	
	$('#monitoring_ledgend').html("Fetching latest logs for Job: "+id);
	$('#logs_monitoring_div').html("");


	try{
		clearInterval(tid);
	}
	catch(e){
		console.log("Error stopping log monitor "+id);
	}
	
	console.log("Starting timer")
	
	var count=0;
	
	tid=setInterval(function(){
		
		if(count>10){
			clearInterval(tid);
			alert("Monitoring has stopped ");
		}
		monitor_logs(id);
		$("#load_logs_button").trigger( 'click');
        
        
		count++;
		
		},10000);

	
}
function monitor_logs(id) {
	//https://datatables.net/examples/server_side/row_details.html
	
	console.log("getting logs "+id);
    datatables();

	
		/*
		 * Ajax lookup of uid to get message
		 */
		
		jQuery.ajax({  
			  type: 'POST',
		      url:  "http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php",
		      data: "get_shortened_monitoring_logs="+id,
		      success: function(data,status,xhr){
		    	  
	
		      try{
		    	  JSON_RESPONSE=data;
		    	  var reponse_code=xhr.status;
		    	  if (reponse_code="200"){
		    		  	   
		    	  }
		    	  else if(reponse_code="404"){
		    		
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404");
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    	  }
		    	  else if(reponse_code="500") {
			    		
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 500 ");
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    	  } 
		      	}//try
		      	catch(e){
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Fatal Catch Error "+e);
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    	}//catch
		      },
		      error: function(xhr, status, error){
		    	
		    	jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404 ");
		  		jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		  		jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    }, 
		    complete: function(data){
	
				var json =$.parseJSON(JSON_RESPONSE);
	
		        $.each(json, function(key, value) {
		        	
		        	
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
						else{
							LEVEL="danger";
							ICON="fa fa fa-times fa-2x";
						}
					}
					else if(key=="MESSAGE"){
						
						try{
							
							$('#monitoring_ledgend').html("Monitoring Job Id:"+id);
							$('#logs_monitoring_div').html(atob(value));
						}
						catch(e){
							$('#monitoring_ledgend').html("Monitoring Job Id:"+id);
							$('#logs_monitoring_div').html("Error decoding logs ");

						}
					}
					
		        });
		    }
		}); 
	  
}

function rollback_orignal_rpm(id,deployment_id) {

	$("#message_installation_logs").removeClass("alert alert-danger");
	$("#message_installation_logs").text("");
	console.log("Rolling back "+id);
	
		/*
		 * Ajax lookup of uid to get message
		 */
		
		jQuery.ajax({  
			  type: 'GET',
		      url:  "http://atrclin3.athtem.eei.ericsson.se/TestScripts/jenkins/enm/teaas/rpm/include/handler.php?rollback_orignal_rpm="+id,
		      success: function(data,status,xhr){
		    	  
		    	  
	
		      try{
		    	  JSON_RESPONSE=data;
		    	  var reponse_code=xhr.status;
		    	  if (reponse_code="200"){
		    		  	   
		    	  }
		    	  else if(reponse_code="404"){
		    		
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404");
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    	  }
		    	  else if(reponse_code="500") {
			    		
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 500 ");
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    		  jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    	  } 
		      	}//try
		      	catch(e){
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).text("Fatal Catch Error "+e);
		    		  jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		    	}//catch
		      },
		      error: function(xhr, status, error){
		    	
		    	jQuery("#"+DIV_DISPLAY_MESSAGE).text("Error 404 ");
		  		jQuery("#"+DIV_DISPLAY_MESSAGE).attr('class','alert alert-danger');
		  		jQuery("#SPINNER").attr('class','fa fa-refresh fa-spin fa-2x');
		    }, 
		    complete: function(data){
	
				var json =$.parseJSON(JSON_RESPONSE);
	
		        $.each(json, function(key, value) {
		        	
		        	
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
						else{
							LEVEL="danger";
							ICON="fa fa fa-times fa-2x";
						}
					}
					else if(key=="MESSAGE"){
						
						try{
							
							$('#monitoring_ledgend').html("Monitoring Job Id:"+id);
							$('#logs_monitoring_div').html(atob(value));
							
							//reload the logs 
							console.log("Reloading logs");
		                    $("#logs_select_deployment").val(deployment_id);
   	                        datatables();
   	                        
   	                        $("#message_installation_logs").addClass("alert alert-danger");
   	                        $('#message_installation_logs').html(value);

		                    
						}
						catch(e){
							console.log("Could not Reload logs");

							//$('#monitoring_ledgend').html("Monitoring Job Id:"+id);
							//$('#logs_monitoring_div').html("Error decoding logs ");

						}
					}
					
		        });
		    }
		}); 
	  
}

function CONVERT_TIME_STAMP_TO_DATE(TABLE_ID){
	
	jQuery('#'+TABLE_ID+" tr").each(function(){
		
		var count=0;
		jQuery(this).find("td").each(function(){
			var td_value=jQuery(this).html()
			
			if(td_value.length=="10" && count>=2){
				
				var date=new Date(td_value*1000);
			    var day = date.getDate();
			    var locale = "en-us";
			    var month = date.toLocaleString(locale, { month: "long" });
			    var year = date.getFullYear();
			    var hours = date.getHours();
			    var minutes = ("0" + date.getMinutes()).substr(-2);
			    var seconds = ("0" + date.getSeconds()).substr(-2); //date.getSeconds();
			    
				jQuery(this).html(day+"/"+month+" "+hours+":"+minutes+":"+seconds);
			}
			count++;
		});
	});
	
}