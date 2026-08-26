from logging import getLogger, StreamHandler, DEBUG
from colorlog import ColoredFormatter


def _get_formatter():
	return ColoredFormatter(
		'%(log_color)s%(asctime)s [%(levelname)-8s] %(message)s',
		datefmt='%Y-%m-%d %H:%M:%S',
		log_colors={
			'DEBUG': 'green',
			'INFO': 'white',
			'WARNING': 'yellow',
			'ERROR': 'red',
			'CRITICAL': 'red,bg_white',
		},
	)


def _get_logger():
	logging_logger = getLogger()
	logging_logger.setLevel(DEBUG)
	console_handler = StreamHandler()
	if console_handler.formatter is None:
		console_handler.setFormatter(_get_formatter())
	logging_logger.addHandler(console_handler)
	return logging_logger


logger = _get_logger()
