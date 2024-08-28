<html>
<header>

    <link rel='stylesheet' href='lib/fullcalendar.min.css' />
    <link rel='stylesheet' href='lib/bootstrap.min.css' />  
    <link rel='stylesheet' href='lib/jquery.qtip.min.css' />
    <link rel='stylesheet' href='lib/style.css' />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    
    
    <script src='lib/jquery-3.1.1.js'></script>
    <script src='javascript/bootstrap.js'></script>
    <script src='javascript/notify.js'></script>
    <script src='lib/jquery.qtip.min.js'></script>
   
    <script src='lib/moment.js'></script>
    <script src='lib/fullcalendar.min.js'></script>
    <script src='javascript/deploy.js'></script>
</header>
<body onload="load_calendar()" >



<nav class="navbar navbar-default ">
        <div class="container-fluid">
          <div class="navbar-header">
            <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">
              <span class="sr-only">Toggle navigation</span>
              <span class="icon-bar"></span>
              <span class="icon-bar"></span>
              <span class="icon-bar"></span>
            </button>

          </div>
           
           
          <div id="navbar" class="navbar-collapse collapse">
            <ul class="nav navbar-nav">
              <li  data-toggle="dropdown" aria-haspopup="" aria-expanded="" class=""><a href="#" >Environments</a><span class=""></span></li>
              <li class="alert-success"><a href="#" onclick='ajax_jira_call("Testing");'>In Testing</a></li>
              <li class="alert-grey"><a href="#" onclick='ajax_jira_call("CLOSED");'>Closed (<60days)</a></li>
              <li class="alert-info"><a href="#" onclick='ajax_jira_call("IN_PROGRESS");'>In Progress </a></li>   
              <li class="alert-danger"><a href="#" onclick='ajax_jira_call("ON_HOLD");'>On Hold</a></li>      
              <li  class="active"><a href="#" onclick='ajax_jira_call("ALL_TICKETS");'>All Tickets</a></li>
              <li  class=""><a href="#" onclick='ajax_jira_call("EXCLUSIVE");'>Exclusive</a></li>
          
          		<ul class="dropdown-menu " >
				    <li><a href="#" onclick='ajax_jira_call("429");'>429</a></li>
				    <li><a href="#" onclick='ajax_jira_call("435");'>435</a></li>
				    <li><a href="#" onclick='ajax_jira_call("431");'>431</a></li>
				    <li><a href="#" onclick='ajax_jira_call("436");'>436</a></li>
				    <li><a href="#" onclick='ajax_jira_call("CIP-19047");'>CIP-19047</a></li>
				    
				    <li role="separator" class="divider"></li>
			  	</ul>
			  	<li class="divider-vertical"></li>
			  	<li class="checkbox-filter">
  					<label><input onclick="applyCheckboxFilters();" checked id="reporter-assignee-checkbox" type="checkbox" value="reporter-assignee">Reporter/Assignee</label>
  					<label><input onclick="applyCheckboxFilters();" checked id="summary-checkbox" type="checkbox" value="summary">Summary</label>
  					<label><input onclick="applyCheckboxFilters();" checked id="status-access-type-checkbox" type="checkbox" value="status-access-type">Status/Access Type</label>
  					
				</li>
			  	
       
            </ul>
            
             
            <i id="spinner_progress" class="fa fa-cog  pull-right hidden " style="font-size:48px;color:green"></i>
            
          </div><!--/.nav-collapse -->
        </div><!--/.container-fluid -->
      </nav>

<div class="calendar-css " id='calendar' ></div>



</body>

</html>

