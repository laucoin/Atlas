from subprocess import run, check_output, CalledProcessError, PIPE
from logger_config import logger

def kill_port(port, debug):
	pids = port_usage(port, debug)

	if (pids is None):
		logger.warning('There is no process to kill')
		return None

	for pid in pids:
		try:
			logger.info(f'Killing process "{pid}"')
			command = ['kill', '-15', pid]
			check_output(command)
		except CalledProcessError as e:
			kill_error_message = f'Failed to kill process `{" ".join(command)}`:\n{e}'
			logger.error(kill_error_message)
			if (debug is True):
				raise CalledProcessError(kill_error_message)
			exit()

def port_usage(port, debug):
	logger.info(f'Scanning "{port}" usage')

	try:
		command = ['lsof', '-i', f':{port}', '-sTCP:LISTEN']
		result = run(command, stdout=PIPE, stderr=PIPE, text=True, check=True)

		if (result.stdout):
			lines = result.stdout.splitlines()
			pids = [line.split()[1] for line in lines if line.strip() and lines.index(line) > 0]
			logger.info(f'Port is in use with PID "{", ".join(pids)}"')
			print(result.stdout)
			return pids
	except CalledProcessError as e:
		logger.info(f'Port "{port}" is not used')

	return None
