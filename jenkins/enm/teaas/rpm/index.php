<html>
<header>

	<link rel='stylesheet' href='css/bootstrap.min.css' />
	<link rel='stylesheet' href='css/jquery-css.css' />
	<link rel='stylesheet' href='css/css.css' />
	<link rel='stylesheet' href='css/index.css' />
	<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
	<link rel='stylesheet' type='text/css' href='http://cdn.datatables.net/1.10.10/css/jquery.dataTables.css'>

	<script src='javascript/jquery-3.1.1.js'></script>
	<script src='javascript/jquery-ui.js'></script>
	<script src='javascript/spin.js'></script>
	<script src='javascript/bootstrap.js'></script>
	<script src='javascript/notify.js'></script>
	<script src='javascript/deployment.js'></script>
	<script src="http://cdn.datatables.net/1.10.10/js/jquery.dataTables.min.js"></script>
	<script src="javascript/datatables.js"></script>
	
	<style>
  #sortable { list-style-type: none; margin: 0; padding: 0; width: 60%; }
  #sortable li { margin: 0 3px 3px 3px; padding: 0.4em; padding-left: 1.5em; font-size: 1.4em; height: 38px; }
  #sortable li span { position: absolute; margin-left: -1.3em; }
  </style>

	<script>
  $( function() {
    $( "#tabs" ).tabs();
  });
  get_jira_list();


  </script>
</header>
<body>

<div align="center" class="torLogin-Holder-nameWrap" id="loginTitle" style="display: table;"><span class="torLogin-Holder-title">Black RPM installer</span></div>



<?php 
require_once("include/ldap.php");

if($_SESSION['rpm']==""){
	
	echo '
	 <div align="center">
			
		<div title="Login" id="loginbox" class="form-horizontal">
		    <div style="">
		    <form action="index.php" id="login" method="post">
		        <table>';if (isset($err)) echo '<span class="alert-danger">'.$err.'</span><hr>';
		        echo '
			
		             <div class="torLogin-Holder-inputWrap">
                    <input type="text" id="username" name="username" autofocus="autofocus" value="" placeholder="Username" class="torLogin-Holder-loginUsername">

                    <div class="torLogin-Holder-inputComposition">
                        <input type="password" id="password" name="password" value="" placeholder="Password" class="torLogin-Holder-loginPassword">
                    </div>
                    <div id="messagesBox" class="torLogin-Holder-messagesBox"></div>
			
                </div>
		        </table>
		        <input class=""torLogin-Holder-formButton"" type="submit" name="submit" value="Login" />
		    </form>
		    </div>
		</div>
		</div>
		'; 
	exit;
	
}

?>



<div id="tabs">
  <ul>
    <li><a href="#tabs-1">Apply RPM</a></li>
    <li><a href="#tabs-2">History</a></li>
  </ul>
		
			<div id="tabs-1" class="form-horizontal">
				<fieldset>
		
				<!-- Multiple Radios -->
				<div class="form-group">
				  <label id="label_deployment_id" class="col-md-4 control-label" for="deploymentid">Deployment ID</label>
				  <div class="col-md-4">
				  <div class="radio" >
				    <label for="deploymentid-0">
				      <input type="radio" name="deploymentid" id="deploymentid-0" value="429" required>
				      429
				    </label>
					</div>
				  <div class="radio">
				    <label for="deploymentid-1">
				      <input type="radio" name="deploymentid" id="deploymentid-1" value="431">
				      431
				    </label>
					</div>
				  <div class="radio">
				    <label for="deploymentid-2">
				      <input type="radio" name="deploymentid" id="deploymentid-2" value="436">
				      436
				    </label>
					</div>
				  </div>
				</div>
				
				<!-- Text input-->
					<div class="form-group">
						<label id="label_rpm_url" class="col-md-4 control-label" for="RPM Url">Rpm Url</label>
						<div class="col-md-4">
							<input id="rpm_url" name="rpm_url" type="text"
								placeholder="RPM Url" class="form-control input-md" required=""> 
								<span class="help-block">eg https://arm1s11-eiffel004.eiffel.gic.ericsson.se:8443/nexus/service/ERICnetworkexplorerimport_CXP9034327-1.0.1.rpm
							</span>
						</div>
					</div>
					
					<!-- Multiple Radios (inline) -->
						<div id="rpm_type_div" class="form-group">
						  <label id="label_install_type" class="col-md-4 control-label" for="radios">RPM Install Type</label>
						  <div class="col-md-4"> 
						    <label class="radio-inline" for="radios-0">
						      <input type="radio" name="install_type" id="radios-0" value="service_rpm">
						      Service RPM
						    </label> 
						    <label class="radio-inline" for="radios-1">
						      <input type="radio" name="install_type" id="radios-1" value="model_rpm">
						      Model RPM
						    </label> 
						  </div>
						</div>
				
				
				
					<!-- Form Name -->
		
					<!-- Text input-->
					<div class="form-group">
						<label id="label-jira-ticket" class="col-md-4 control-label" for="RPM Url">Associated Jira Ticket</label>
						<div class="col-md-4">
							<input value="" id="jira-ticket-input" name="jira-ticket-input" type="text" placeholder="Jira Ticket" class="form-control input-md" required="" disabled> 
								<span class="help-block">eg: CIP-88778
							</span>
						</div>
					</div>
					
					
					
					<!-- Button -->
					<div class="form-group">
					  <label id="label_step_1" class="col-md-4 control-label" for="Next Step">Click </label>
					  <div class="col-md-4">
					    <button onclick="step_1();" id="button_step_1" name="button_step_1" class="btn btn-primary">Next Step</button>
					  </div>
					</div>
			<hr>
			
					<!-- Select Multiple -->
				<div id="select-service-groups_div" class="form-group hidden">
				  <label class="col-md-4 control-label" for="select-service-groups">Service Groups</label>
				  <div class="col-md-5">
				    <select onclick="service_group_select();" id="select-service-groups" name="select-service-groups" class="form-control" multiple="multiple" style='height: 50%;'>
				    <option>this</option>
				    <option>this2</option>
				    </select>
				  </div>
				</div>
			
				
				<div id="select_service_group_options_div" class="form-group hidden">
				<label id="label_step_2" class="col-md-4 control-label" for="select-service-groups">Select Order to offline Service Groups(Draggable)</label>
				  <div class="col-md-5">
					<ul id="sortable">
					</ul>
				</div>
				</div>
				<!-- Button -->
					<div id="apply-rpm-button" class="form-group hidden">
					  <label id="label_install_rpm" class="col-md-4 control-label" for="Next Step"></label>
					  <div class="col-md-4">
					    <button onclick="install_rpm();" id="button_step_2" name="button_step_2" class="btn btn-success">Install RPM</button>
					  </div>
					</div>
				</fieldset>
				
				<form action="index.php" id="login" method="post">
					<input class="pull-right" name="logout" type="submit" name="submit" value="Logout" />
				</form>
			</div>

			<div id="tabs-2">
			
				<?php require_once("include/tables.php");?>
			
			</div>

</body>


