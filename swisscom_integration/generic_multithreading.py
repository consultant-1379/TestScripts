#!/usr/bin/python
#
# ***************************************************************************
# Name    : generic.py
# Purpose : Generic script to run ENM CLI commands  using enm_scripting library
# Version : 1.5
# ***************************************************************************
#
import enmscripting as enm
import logging
import signal
import sys
import threading
import traceback

# ENM proxy FQDN settings
#ENM_URL = "https://ieatENM5297-1.athtem.eei.ericsson.se"
USERNAME = "administrator"
PASSWORD = ""

LOGGING_ENABLED = True
LOG_NAME = "generic_multithread_debug.log"
LOGGING_LEVEL = logging.INFO
logger = None


class CommandThread(threading.Thread):
    def __init__(self, thread_id, session, cli_command):
        threading.Thread.__init__(self)
        self.thread_id = thread_id
        self.session = session
        self.cli_command = cli_command
        self.setDaemon(True)

    def run(self):
        # Run the command
        response_lines = execute_cli_command_for_thread(self.thread_id, self.session, self.cli_command)

        # Log the response
        [logger.info(line) for line in response_lines]


def execute_cli_command_for_thread(command_thread_id, session, command, file=None):
    """
    Executes the ENM CLI command using an enmscripting session object and returns the output as a list of strings.
    A single string in the list represents one line of text output generated from the command (identical to running the command on the ENM GUI).
    Depending on the command response, these strings may contain tab separated content.

    @type command_thread_id: int
    @param command_thread_id: The thread ID of the commandThread being executed
    @type session: enmscripting.Session
    @param session: Session object used to create a terminal instance and execute the command towards the ENM deployment
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
    
    terminal = session.terminal()
    terminal_output = terminal.execute(command, file=file)

    command_output = terminal_output.get_output()

    logger.info("Command Response: [Thread ID {0}]".format(command_thread_id))

    check_response_for_error(command_output)

    # Check if the terminal response has any files and if so download them
    has_files = terminal_output.has_files()
    if has_files:
        logger.debug("Command response contains files, Downloading them... [Thread ID {0}]".format(command_thread_id))
        for f in terminal_output.files():
            logger.debug("Downloading file {0} [Thread ID {1}]".format(f.get_name(), command_thread_id))
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

    logger.error("An error has occurred, please see the debug log for more details")
    logger.error("Exception occurred: '{0}'".format(e))

    # Get the exception information from the stackframe
    (exc_type, exc_value, exc_traceback) = sys.exc_info()

    exception_lines = []
    exception_lines.append("")

    if exc_type is not None and exc_value is not None and exc_traceback is not None:
        # Build up the exception stack
        exception_lines.append("EXCEPTION: " + str(exc_type.__name__) + " - " + str(exc_value))
        exception_lines.append("")
        exception_lines.append("STACK TRACE")
        exception_lines.append("-----------")
        exception_lines.append("")

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
    [logger.error(line) for line in exception_lines]


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
    if len(sys.argv) > 3:
        print "Invalid Number of arguments\n"
        _print_usage()

    if sys.argv[1] in ["help", "-h", "--help"]:
        _print_usage()


def _init_logger():
    """
    Sets up info and debug log handlers

    @rtype void
    """

    # Get a reference to the root logger
    global logger, LOGGING_ENABLED
    logger = logging.getLogger("")

    if not LOGGING_ENABLED:
        # Prevent logging being sent to the root logger
        logger.propagate = False
    else:
        # Set the global log level as configured
        logger.setLevel(LOGGING_LEVEL)

        # Create handler for INFO level (console handler)
        ch = logging.StreamHandler(sys.stdout)
        ch.setLevel(logging.INFO)
        # Create formatter for console handler handler
        formatter = logging.Formatter('%(message)s')
        ch.setFormatter(formatter)
        logger.addHandler(ch)

        # Create handler for DEBUG level (file handler)
        fh = logging.FileHandler(LOG_NAME)
        fh.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s %(levelname)s - %(message)s')
        fh.setFormatter(formatter)
        logger.addHandler(fh)


def _signal_handler(signal, frame):
    """
    Registers a signal handler which will get executed when the user hits ctrl+c
    
    @rtype void
    """

    logger.debug("Interrupt signal recieved, shutting down...")
    sys.exit(0)


def execute_cli_commands_multithreaded(session, cli_commands):
    """
    Creates a list of one or more CommandThread objects (for each cli command passed in) and runs these threads in parallel
    Method return type is void, responses are logged with info handler

    :param session: enm session
    :param cli_commands: list of CLI commands
    :return: void
    """

    command_thread_list = []

    # create command threads for each command
    thread_id = 0
    for command in cli_commands:
        command_thread = CommandThread(thread_id, session, command)
        command_thread_list.append(command_thread)
        thread_id = thread_id + 1

    # Start the threads
    [command_thread.start() for command_thread in command_thread_list]

    # Wait for all threads to complete
    [command_thread.join() for command_thread in command_thread_list]


def main():
    # Register signal handler for keybaord interrupts
    signal.signal(signal.SIGINT, _signal_handler)

    _validate_args()

    script_result = True
    rc = 0

    # Parse the ENM CLI command(s) that was provided - multiple commands are delimited with a semi colon
    cli_commands = sys.argv[1].strip().split(";")

    # Check if an extra arg was passed to disable logging
    if (len(sys.argv) == 3 and sys.argv[2] == "--log=false"):
        global LOGGING_ENABLED
        LOGGING_ENABLED = False

    _init_logger()

    # Create an ENM session
    session = None
    try:
        session = enm.open(ENM_URL, USERNAME, PASSWORD)

        # Run the command(s) in a multi threaded manner sharing the session object
        execute_cli_commands_multithreaded(session, cli_commands)

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
