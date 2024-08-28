

<!-- Select Basic -->
<div class="form-group">
  <button onclick="datatables();" id="load_logs_button" name="" class="btn btn-success">Load Logs</button>
  <div class="col-md-4">
    <select id="logs_select_deployment" name="selectbasic" class="form-control">
      <option value="">Select Deployment</option>
      <option value="429">429</option>
      <option value="431">431</option>
      <option value="436">436</option>
    </select>    
  </div>
</div>
    <label id="message_installation_logs" class="control-label pull-right"></label>

    <div id="DIV_TICKETS_TABLE" class="">
		<legend>RPM Installation Logs</legend>
		<table id="DATA_TABLES_TICKETS" class="display" cellspacing="0"
			width="100%">
			<thead>
				<tr>
					<th>id</th>
					<th>eid</th>
					<th>Deployment</th>
					<th>Jira Ticket</th>
					<th>RPM Url</th>
					<th>Orignal Rpm</th>
					<th>Service Groups</th>
					<th>Status</th>
					<th>Started</th>
					<th>Actions</th>
	
	
	
				</tr>
			</thead>
		</table>
	</div>

<div id="" class="">
		<legend id ="monitoring_ledgend">...</legend>
		<div id="logs_monitoring_div"></div>
		
		
</div>

