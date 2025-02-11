module dotenv

import os

fn parse(filepath string) ! {
	content := os.read_file(filepath)!

	for line in content.split_into_lines() {
		if line.starts_with('#') {
			continue
		}

		if k, v := line.split_once('=') {
			os.setenv(k, v, true)
		}
	}
}

pub fn load() ! {
	exe := os.executable()

	cwd := if os.is_link(os.executable()) {
		real_path := os.real_path(exe)
		os.dir(real_path)
	} else {
		os.getwd()
	}

	dotenv_filepath := os.join_path(cwd, '.env')
	return parse(dotenv_filepath)
}
