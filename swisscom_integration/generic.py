#!/usr/bin/python
#
# ***************************************************************************
# Name    : generic.py
# Purpose : Generic script to run ENM CLI commands  using enm_scripting library
# Version : 1.5
# ***************************************************************************
#
import sys
import logging
import signal
import traceback
import enmscripting as enm

# ENM proxy FQDN settings
ENM_URL = "https://henmp-haproxy.sharedtcs.net"
USERNAME = "nbicm1"
PASSWORD = 

LOG_NAME = "generic_debug.log"
logger = None

def execute_enm_cli_command(terminal, command, file=None):
    """
    Executes the ENM CLI command using an enmscripting terminal instance and returns the output as a list of strings.
    A single string in the list represents one line of text output generated from the command (identical to running the command on the ENM GUI).
    Depending on the command response, these strings may contain tab separated content.

    @type terminal: enmscripting.EnmTerminal
    @param terminal: Terminal object used to execute the command towards the ENM deployment
    @type command: str
    @type file: File object
    @param file: File object to be imported  - optional parameter - needed if the command requires a file for upload
    @param command: The CLI command to be executed. For more information about a command's syntax,
            please check the web-cli online help
    @return: List of strings representing the output from the command. Lines are single strings.
            Table rows are single strings with tabs delimiting columns
    @rtype: list <str>
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

    print "Usage: {0} '<enm_cli_command>'\n".format(sys.argv[0])
    print "Example(s): {0} '{1}'".format(sys.argv[0], "cmedit get * MeContext")
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

    # Parse the ENM CLI command that was provided
    cli_command = sys.argv[1].strip()

    # Check if the command contains a ";" character and split this into separate commands
    cli_commands = None
    if ";" in cli_command:
        cli_commands = cli_command.split(";")

    # Create an ENM session
    session = None
    try:
        logger.debug("Attempting to connect to ENM URL '{0}' to create a terminal session".format(ENM_URL))
        session = enm.open(ENM_URL, USERNAME, PASSWORD) 

        # Create a terminal instance from this session
        terminal = session.terminal()

        if cli_commands is not None:
            # Run each CLI command that was passed in sequentially
            for cli_command in cli_commands:
                response_lines = execute_enm_cli_command(terminal, cli_command)

                for line in response_lines:
                    print line

                print "\n"
        else:
            # Execute the single ENM CLI command using the terminal instance, this returns the response as a list of strings
            response_lines = execute_enm_cli_command(terminal, cli_command)

            for line in response_lines:
                print line

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

