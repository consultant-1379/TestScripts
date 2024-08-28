#!/usr/bin/python
#
# **********************************************************
# Name    : cm_bulk_import.py
# Purpose : Executes a CM bulk import with the specified xml
# Version : 1.3
# **********************************************************
#
import os
import sys
import logging
import signal
import time
import datetime
import traceback
import enmscripting as enm

# ENM proxy FQDN settings
ENM_URL = "https://henmp-haproxy.sharedtcs.net"
USERNAME = "nbicm1"
PASSWORD = 

# CM Import CLI Commands
CM_CONFIG_CREATE_COMMAND =  "config create {NON_LIVE_CONFIG_NAME}"
CM_LIST_CONFIG_COMMAND = "config list"

CM_CONFIG_COPY_COMMAND = "config copy --ne * -s Live -t {NON_LIVE_CONFIG_NAME}"
EXPECTED_CONFIG_COPY_RESPONSE = "Copy nodes started with job ID"
CM_CONFIG_COPY_STATUS_COMMAND = "config copy --status --job {JOB_ID} --detail"

CMEDIT_IMPORT_COMMAND = "cmedit import file:{XML_FILENAME} -f=3GPP -c={NON_LIVE_CONFIG_NAME}"
CMEDIT_IMPORT_STATUS_COMMAND = "cmedit import --status --job={JOB_ID} --detail"

CM_CONFIG_ACTIVATE_COMMAND = "config activate --source {NON_LIVE_CONFIG_NAME}"
CM_CONFIG_ACTIVATE_STATUS_COMMAND = "config activate --status --job {JOB_ID}"

CM_CONFIG_DELETE_COMMAND = "config delete {NON_LIVE_CONFIG_NAME}"

# Set this flag to false to not delete the config if there is any error  
DELETE_CONFIG_ON_ERROR = True

# Polling configuration for job status (in seconds)
POLLING_INTERVAL = 1
POLLING_TIMEOUT = 30

LOG_NAME = "cm_bulk_import_debug.log"
logger = None

def execute_enm_cli_command(terminal, command, file=None):
    """
    Executes the ENM CLI command using an enmscripting terminal instance and returns the output as a list of strings. 
    A single string in the list represents one line of text output generated from the command (identical to running the command on the ENM GUI).
    Depending on the command response, these strings may contain tab separated content.
    This function also raises a RuntimeError if the response contains an error in the last two lines of the response output

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type command: str
    @param command: The CLI command to be executed. For more information about a command's syntax,
            please check the web-cli online 
    @type file: File object
    @param file: File object to be imported  - optional parameter - needed if the command requires a file for upload
    @rtype: list <str>
    @return: List of strings representing the output from the command. Lines are single strings.
            Table rows are single strings with tabs delimiting columns
    @raises: RuntimeError
    """

    logger.info("Executing ENM command '{0}'".format(command))
    terminal_output = terminal.execute(command, file=file)

    # Verify the command was sent successfully
    if terminal_output.is_command_result_available():
        logger.debug("Command was sent successfully and a response code of '{0}'' was received".format(terminal_output.http_response_code()))
    else:
        logger.error("Command was not sent successfully")

    command_output = terminal_output.get_output()

    logger.info("\nCommand Response: {0}\n".format(command_output))

    check_response_for_error(command_output)

    # Check if the terminal response has any files and if so download them 
    has_files = terminal_output.has_files()
    if has_files:
        logger.debug("Command response contains files, Downloading them...")
        for f in terminal_output.files():
            logger.debug("Downloading file {0}".format(f.get_name()))
            f.download()

    return command_output

def check_response_for_error(command_output):
    """
    Checks if the command output contains any known error strings in the response. 
    Rather than checking all lines in the response we are just checking the last 2 lines.

    @type command_output: str
    @param command_output: The command output response
    @rtype: void
    @raises RuntimeError
    """
    
    if any("Error" in line or "Invalid" in line or "Unsupported" in line for line in command_output[-2:]):
        raise RuntimeError("'Error' string found in response output '{0}'".format(command_output))

def create_non_live_config(terminal, config_name):
    """
    Executes the cm export command and returns the job ID

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @rtype: void 
    @raises RuntimeError
    """
    
    # Issue the command to create the non live config
    execute_enm_cli_command(terminal, CM_CONFIG_CREATE_COMMAND.format(NON_LIVE_CONFIG_NAME=config_name))

    # Check the config was created
    response_lines = execute_enm_cli_command(terminal, CM_LIST_CONFIG_COMMAND)
    if config_name not in response_lines:
        raise RuntimeError("Config '{0}' was not successfully created".format(config_name))

def copy_live_network_to_non_live_config(terminal, config_name):
    """
    Executes the cm config copy command to copy the live network into the non-live config 

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type config_name: str
    @param config_name: The name of the non live config
    @rtype: void
    @raises: RuntimeError
    """

    # Issue the command to copy the live config into the non-live config
    config_copy_response_lines = execute_enm_cli_command(terminal, CM_CONFIG_COPY_COMMAND.format(NON_LIVE_CONFIG_NAME=config_name))

    # Check that we get a single line response and that it contains the expected text
    if len(config_copy_response_lines) != 1 and not any(EXPECTED_CONFIG_COPY_RESPONSE in line for line in config_copy_response_lines):
        raise RuntimeError("CM config copy command did not contain expected response '{0}'".format(EXPECTED_CONFIG_COPY_RESPONSE))

    # Get the Job ID
    # Parse the single line from the response into a list, this allows us to read each word in the string as a list index
    single_line = config_copy_response_lines[0]
    single_line_as_list = single_line.split()
    
    # Get the job ID from the response (should be the last value in the list)
    job_id = single_line_as_list[-1]
    logger.info("CM config copy started with Job ID = {0}".format(job_id))

    # Wait until the job status is COMPLETE 
    poll_for_job_status_complete(terminal, CM_CONFIG_COPY_STATUS_COMMAND.format(JOB_ID=job_id))

def import_config(terminal, xml_filename, config_name):
    """
    Runs a cmedit import command substituting the xml filename as the name of the non live config and passing the xml file to the command request 

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type xml_filename: str
    @param xml_filename: The name of the import XML file
    @type config_name: str
    @param config_name: The name of the non live config
    @raises: RuntimeError
    """

    with open(xml_filename, 'rb') as file_to_import:
        command = CMEDIT_IMPORT_COMMAND.format(XML_FILENAME=os.path.basename(xml_filename), NON_LIVE_CONFIG_NAME=config_name)
        import_response_lines = execute_enm_cli_command(terminal, command, file=file_to_import)

    expected_response_length = 3

    # Get the job ID and check if the import went ok
    if import_response_lines is not None and len(import_response_lines) == expected_response_length:
        # Parse the single line from the response into a list, this allows us to read each word in the string as a list index
        single_line = import_response_lines[0]
        single_line_as_list = single_line.split()

        # Get the job ID from the response (should be the last value in the list)
        job_id = single_line_as_list[-1]
        logger.info("CM Import started with Job ID = {0}".format(job_id))

        # Wait until the job status is COMPLETE 
        poll_for_job_status_complete(terminal, CMEDIT_IMPORT_STATUS_COMMAND.format(JOB_ID=job_id))
    else:
        raise RuntimeError("Cm import command did not return expected response, could not get the job ID from the response")

def activate_config(terminal, config_name):
    """
    Activates the the cm config 

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type config_name: str
    @param config_name: The name of the non live config
    @rtype: void
    @raises: RuntimeError
    """

    activate_response_lines = execute_enm_cli_command(terminal, CM_CONFIG_ACTIVATE_COMMAND.format(NON_LIVE_CONFIG_NAME=config_name))

    expected_response_length = 1

    # Get the job ID and check if the import went ok
    if activate_response_lines is not None and len(activate_response_lines) == expected_response_length:
        # Parse the single line from the response into a list, this allows us to read each word in the string as a list index
        single_line = activate_response_lines[0]
        single_line_as_list = single_line.split()
        
        # Get the job ID from the response (should be the last value in the list)
        job_id = single_line_as_list[-1]
        logger.info("CM Activate started with Job ID = {0}".format(job_id))

        # Wait until the job status is COMPLETE 
        poll_for_job_status_complete(terminal, CM_CONFIG_ACTIVATE_STATUS_COMMAND.format(JOB_ID=job_id))
    else:
        raise RuntimeError("Cm Activate command did not return expected response, could not get the job ID from the response")

def poll_for_job_status_complete(terminal, command):
    """
    Runs the CM status command with the polling interval (specified at top of script) until either the job status becomes COMPLETE, FAILED, or the timeout is reached 
    Raises a RuntimeError if the job status does not return COMPLETE

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type: command: str
    @param command: The cm status command
    @rtype: void
    @raises: RuntimeError
    """

    # Check if the job status is completed, otherwise poll until it is or timeout expires
    end_time = datetime.datetime.now() + datetime.timedelta(seconds=POLLING_TIMEOUT)

    while datetime.datetime.now() < end_time:    
        logger.debug("Checking to see if the job status is COMPLETE with command '{0}'".format(command))

        status = check_cm_command_status(terminal, command)
        if "COMPLETED" in status:
            break

        # Fail fast if the job status failed
        if "FAILED" in status:
            raise RuntimeError("Job status returned a fail, no longer polling for job success")

        # Sleep a bit before we try again
        time.sleep(POLLING_INTERVAL)
    else:
        raise RuntimeError("Timeout reached polling for job status to become COMPLETE")

def check_cm_command_status(terminal, command):
    """
    Runs a standard CM status command (with job ID embedded in the command) and returns the Job status.

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type: command: str
    @param command: The cm status command
    @rtype: str
    @return: The job status of the CM command
    @raises: RuntimeError
    """

    command_status_response_lines = execute_enm_cli_command(terminal, command)

    # Get the row of values from the response lines, the status value is on line/row 3
    if not len(command_status_response_lines) >=3:
        raise RuntimeError("CM status command did not return expected response, could not check the job status")

    row_values = command_status_response_lines[2]

    # These values are tab delimited, so split on this and then retrieve what we want from the list
    row_values = row_values.split("\t")
    if len(row_values) > 2:
        job_status = row_values[1]
        logger.info("CM job status = {0}".format(job_status))
        return job_status
    else:
        raise RuntimeError("CM status command did not return expected response, could not check the job status")
           
def delete_config(terminal, config_name):
    """
    Deletes a config

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type config_name: str
    @param config_name: The name of the non live config
    @rtype: void
    @raises: RuntimeError
    """

    delete_response_lines = execute_enm_cli_command(terminal, CM_CONFIG_DELETE_COMMAND.format(NON_LIVE_CONFIG_NAME=config_name))

    # Get the job ID and check if the import went ok
    if delete_response_lines is not None and len(delete_response_lines) == 1:
        # Parse the single line from the response into a list, this allows us to read each word in the string as a list index
        single_line = delete_response_lines[0]
        single_line_as_list = single_line.split()
        
        # Get the job ID from the response (should be the last value in the list)
        job_id = single_line_as_list[-1]
        logger.info("CM delete config started with Job ID = {0}".format(job_id))
    else:
        raise RuntimeError("Cm delete config command did not return expected response, could not get the job ID from the response")

def _log_exception(e):
    """
    Logs the exception message and the stack trace

    @type e: Exception
    @param e: The exception object
    """

    print "An error has occurred, please see the debug log for more details"
    logger.error("Exception occurred: '{0}'".format(e))

    # Get the exception information from the stackframe
    (exc_type, exc_value, exc_traceback) = sys.exc_info()

    exception_lines = []
    exception_lines.append("")

    if exc_type is not None and exc_value is not None and exc_traceback is not None:
        # Print out the exception
        exception_lines.append("EXCEPTION: " + str(exc_type.__name__) + " - " + str(exc_value))
        exception_lines.append("")
        exception_lines.append("STACK TRACE")
        exception_lines.append("-----------")
        exception_lines.append("")

        # Get the exception stack as a list        
        exception_list = traceback.extract_tb(exc_traceback)
        for counter in range((len(exception_list) - 1), -1, -1):
            exception_tuple = exception_list[counter]
            if len(exception_tuple) >= 4:
                filename = exception_tuple[0]
                line_num = exception_tuple[1]
                function_name = exception_tuple[2]
                line = exception_tuple[3]

                # Print out the standard exception info
                if "<module>" in function_name:
                    exception_lines.append("[" + str(counter + 1) + "] LINE " + str(line_num) + " OF FILE " + filename)
                elif exc_traceback is not None:
                    exception_lines.append("[" + str(counter + 1) + "] LINE " + str(line_num) + " OF FILE " + filename)
                else:
                    exception_lines.append("[" + str(counter + 1) + "] LINE " + str(line_num) + " OF FILE " + filename)

                if line is not None and len(line) > 0:
                    exception_lines.append("    LINE: " + line.strip())

    exception_lines.append("")

    # Log the exception
    for line in exception_lines:
        logging.error(line)

def _print_usage():
    """
    Prints the help text to the console and exits

    @rtype: void
    """

    print "Usage: {0} '<xml_file_path>'\n".format(sys.argv[0])
    print "Example(s): {0} '{1}'".format(sys.argv[0], "/var/tmp/2015-11-19_TGDSCS00_OLMP11_features")
    print "\n"
    sys.exit(0)

def _validate_args():
    """
    Checks if the number of arguments provided to the script is/are correct

    @rtype: void
    """

    # Check correct number of arguments provided
    if len(sys.argv) != 2:
        print "Invalid Number of arguments\n"
        _print_usage()
    if sys.argv[1] in ["help", "-h", "--help"]:
        _print_usage()

def _init_logger():
    """
    Configures the logger to write to file

    @rtype void
    """

    # Set up logging to file, formatter etc.
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)-8s %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S',
                    filename=LOG_NAME)

    # Set the global logger to use the root logger defined above
    global logger
    logger = logging.getLogger("")

def _signal_handler(signal, frame):
    """
    Registers a signal handler which will get executed when the user hits ctrl+c
    
    @rtype void
    """

    logger.debug("Interrupt signal recieved, shutting down...")
    sys.exit(0)

def main():
    # Register signal handler for keybaord interrupts
    signal.signal(signal.SIGINT, _signal_handler)

    _init_logger()

    _validate_args()

    script_result = True
    rc = 0

    # Create an ENM session
    session = None
    terminal = None
    try:  
        # Parse the xml file to use for the import
        xml_import_file_path = sys.argv[1].strip()

        # Check that the xml file exists
        if not os.path.exists(os.path.realpath(xml_import_file_path)):
            raise RuntimeError("XML file '{0}' does not exist, can not run cm import.".format(xml_import_file_path))

        logger.debug("Attempting to connect to ENM URL '{0}' to create a terminal session".format(ENM_URL))
        session = enm.open(ENM_URL, USERNAME, PASSWORD) 

        # Create a terminal instance from this session
        terminal = session.terminal()

        # Strip the .xml extension from the filename, we will use this string as the non-live config name
        config_name = os.path.basename(xml_import_file_path).strip(".xml")

        # Create the non live config (using the xml filename as the name for the config)
        create_non_live_config(terminal, config_name)

        # Copy the live network into the non-live and get the job ID
        copy_live_network_to_non_live_config(terminal, config_name)

        # Import the configuration xml file
        import_config(terminal, xml_import_file_path, config_name)

        # Activate the config
        activate_config(terminal, config_name)

        # Delete the non-live config
        delete_config(terminal, config_name)

        # Check that the config no longer exists (i.e. delete worked)
        response_lines = execute_enm_cli_command(terminal, CM_LIST_CONFIG_COMMAND)
        if config_name in response_lines:
            raise RuntimeError("Config '{0}' was not successfully deleted".format(config_name))

    except Exception as e:
        _log_exception(e)
        rc = 5
        script_result = False
        # In the case of an error/exception - the config will only be deleted if DELETE_CONFIG_ON_ERROR flag is set to True
        if DELETE_CONFIG_ON_ERROR and terminal is not None:
            logger.info("An exception has occurred - Deleting config as instructed")
            delete_config(terminal, config_name)
    finally:
        # Terminate the ENM terminal session
        if session is not None:
            enm.close(session)

    if not script_result:
        rc = 1

    sys.exit(rc)

if __name__ == '__main__':
    main()