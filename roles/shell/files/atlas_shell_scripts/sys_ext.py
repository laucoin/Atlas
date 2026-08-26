from click import group, option, argument
from port import kill_port, port_usage
from logger_config import logger

@group()
def sys_ext():
	"""This is a system cli extension"""
	pass

@sys_ext.command(context_settings={'show_default': True})
@argument('port', type=int)
@option('-d', '--debug', is_flag=True, help='Debug mode')
def kport(port, debug):
	# Description
	"""Used to kill process linked to specified port"""

	# Checking options
	check_port(port, debug)

	# Calling method
	return kill_port(port, debug)

@sys_ext.command(context_settings={'show_default': True})
@argument('port', type=int)
@option('-d', '--debug', is_flag=True, help='Debug mode')
def uport(port, debug):
	# Description
	"""Used to scan port usage"""

	# Checking options
	check_port(port, debug)

	# Calling method
	return port_usage(port, debug)

def check_port(port, debug):
	# Checking options — valid TCP/UDP ports are 1-65535
	if not (0 < port <= 65535):
		port_error_message = f'Specified port "{port}" should be between 0 and 65535'
		logger.error(port_error_message)
		if (debug is True):
			raise AttributeError(port_error_message)
		exit()

if __name__ == '__main__':
	sys_ext()
