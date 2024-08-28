#!/usr/bin/python
#
# ******************************************************************************************************
# Name    : cm_bulk_export.py
# Purpose : Runs a CM bulk export remotely on ENM via CM CLI generating a specifically named export file.
#			This file is then copied from the source SFS destination to the specified directory
# Version : 1.4
# ******************************************************************************************************
#
import sys
import logging
import signal
import time
import datetime
import traceback
import enmscripting as enm
import shutil

# ENM proxy FQDN settings
ENM_URL = "https://henmp-haproxy.sharedtcs.net"
USERNAME = "nbicm1"
PASSWORD = "xxx" 

JOB_NAME = "LRAN_TOPOLOGY"

# CM Export CLI Commands
CMEDIT_EXPORT_REMOVE_JOB_CMD = "cmedit export -rm -jn={0}".format(JOB_NAME)
CMEDIT_EXPORT_CMD = "cmedit export * --filetype=3GPP -jn={0}".format(JOB_NAME)
EXPECTED_EXPORT_RESPONSE = "Export job {0} started with job ID".format(JOB_NAME)
CMEDIT_STATUS_CMD = "cmedit export --status -j={JOB_ID}"
CMEDIT_DOWNLOAD_EXPORT_FILE_CMD = "cmedit export -dl -j={JOB_ID}"

# Polling configuration for job status (in seconds)
POLLING_INTERVAL = 300 
POLLING_TIMEOUT = 7200

# Script configuration
DIRECTORY_WITH_GENERATED_EXPORT_FILE = "/ericsson/batch/data/export/3gpp_export/"
DIRECTORY_TO_STORE_EXPORT_FILE = "/home/shared/nbicm1/TEST_MOUNT/"

LOG_NAME = "cm_bulk_export_debug.log"
logger = None

class CMException(Exception):
    pass

def execute_enm_cli_command(terminal, command):
    """
    Executes the ENM CLI command using an enmscripting terminal instance and returns the output as a list of strings. 
    A single string in the list represents one line of text output generated from the command (identical to running the command on the ENM GUI).
    Depending on the command response, these strings may contain tab separated content.
    This function also raises a RuntimeError if the response contains an error in the last two lines of the response output

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type command: str
    @param command: The CLI command to be executed. For more information about a command's syntax,
            please check the web-cli online help
    @rtype: list <str>
    @return: List of strings representing the output from the command. Lines are single strings.
            Table rows are single strings with tabs delimiting columns
    @raises: RuntimeError
    """

    logger.info("Executing ENM command '{0}'".format(command))
    terminal_output = terminal.execute(command)

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

def run_cmexport(terminal):
    """
    Executes the cm export command and returns the job ID

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @rtype: str
    @return: The job ID of the export job
    @raises RuntimeError
    """

    # Issue the cmexport command
    cm_export_response_lines = execute_enm_cli_command(terminal, CMEDIT_EXPORT_CMD)

    # Check that we get a single line response and that it contains the expected text
    if len(cm_export_response_lines) != 1 and not any(EXPECTED_EXPORT_RESPONSE in line for line in cm_export_response_lines):
        raise RuntimeError("Cmedit export command did not contain expected response '{0}'".format(EXPECTED_EXPORT_RESPONSE))

    # Get the Job ID
    # Parse the single line from the response into a list, this allows us to read each word in the string as a list index
    single_line = cm_export_response_lines[0]
    single_line_as_list = single_line.split()
    
    # Get the job ID from the response (should be the last value in the list)
    job_id = single_line_as_list[-1]
    logger.info("CM Export started with Job ID = {0}".format(job_id))
    print "CM Export started with Job ID '{0}'".format(job_id)

    return job_id

def get_cmexport_status(terminal, job_id):
    """
    Executes the cm export status command and returns the status value 

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type job_id: str
    @param job_id: The export job ID
    @rtype: str
    @return: The job status
    @raises RuntimeError
    """

    cm_status_response_lines = execute_enm_cli_command(terminal, CMEDIT_STATUS_CMD.format(JOB_ID=job_id))

    # Get the row of values from the response lines
    if len(cm_status_response_lines) != 3:
        raise RuntimeError("Cmedit status command did not return expected response, could not check the job status")

    row_values = cm_status_response_lines[2]

    # These values are tab delimited, so split on this and then retrieve what we want from the list
    row_values = row_values.split("\t")
    if len(row_values) > 3:
        job_status = row_values[2]
        logger.info("Job status = {0}".format(job_status))
        print "Job Status = {0}".format(job_status)
        return job_status
    else:
        raise RuntimeError("Cmedit status command did not return expected response, could not check the job status")

def check_cmexport_status(terminal, job_id):
    """
    Checks to see if the export command was a success, this command will poll until the job status is COMPLETED. 
    Please see the polling configuration values at the top of this script if you wish to change.

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type job_id: str
    @param job_id: The export job ID
    @rtype: void
    @raises RuntimeError
    """

    # Check if the job status is completed, otherwise poll until it is or timeout expires
    end_time = datetime.datetime.now() + datetime.timedelta(seconds=POLLING_TIMEOUT)

    while datetime.datetime.now() < end_time:    
        logger.debug("Checking to see if the export job status is COMPLETE")

        if "COMPLETED" in get_cmexport_status(terminal, job_id):
            break

        # Fail fast if the job status failed
        if "FAILED" in get_cmexport_status(terminal, job_id):
            raise RuntimeError("Job status returned a fail, no longer polling for job success")

        # Sleep a bit before we try again
        time.sleep(POLLING_INTERVAL)
    else:
        logger.debug("Timeout reached")

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

    print "Usage: {0}\n".format(sys.argv[0])
    print "Example(s): {0}".format(sys.argv[0])
    print "\n"
    sys.exit(0)

def _validate_args():
    """
    Checks if the number of arguments provided to the script is/are correct

    @rtype: void
    """

    # Check correct number of arguments provided
    if len(sys.argv) > 1 and sys.argv[1] in ["help", "-h", "--help"]:
        _print_usage()
    elif len(sys.argv) > 1:
        print "No arguments necessary for this script\n"
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
    try:
        logger.debug("Attempting to connect to ENM URL '{0}' to create a terminal session".format(ENM_URL))
        session = enm.open(ENM_URL, USERNAME, PASSWORD) 

        # Create a terminal instance from this session
        terminal = session.terminal()

        # Remove the existing job if it already exists as CM export can not create a job with an identical name 
        print "Removing existing job '{0}' (If it exists)".format(JOB_NAME)
        try:
            execute_enm_cli_command(terminal, CMEDIT_EXPORT_REMOVE_JOB_CMD)
        except CMException as e:
            logger.info("Could not remove job '{0}', likely that it doesn't exist. Continuing...".format(JOB_NAME))
            pass

        # Run the CM Export
        job_id = run_cmexport(terminal)

        # Check the status of the job using the job ID (Poll if not completed)
        check_cmexport_status(terminal, job_id)

        # Move the generated xml file to the specified directory
        shutil.copy("{0}/{1}.xml".format(DIRECTORY_WITH_GENERATED_EXPORT_FILE, JOB_NAME), "{0}/{1}.xml".format(DIRECTORY_TO_STORE_EXPORT_FILE, JOB_NAME))

    except Exception as e:
        _log_exception(e)
        rc = 5
        script_result = False
    finally:
        # Terminate the ENM terminal session
        if session is not None:
            enm.close(session)

    if not script_result:
        rc = 1

    sys.exit(rc)

if __name__ == '__main__':
    main()
