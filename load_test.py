#!/usr/bin/python3

import requests
import argparse
import docker
import os
from time import sleep


def start_container(client, image, basedir):
    volumes = {
        basedir: {
            'bind': '/app',
        },
        '/tmp/data/dump': {
            'bind': '/data/dump',
        },
        '/lib/modules': {
            'bind': '/lib/modules',
            'mode': 'ro'
        },
    }
    tmpfs = {'/run': ''}
    container = client.containers.run(image, command='/bin/sleep 3600',
        volumes=volumes, tmpfs=tmpfs, privileged=True, working_dir='/app',
        detach=True, remove=True)
    return container

def test_software(i, url):
    for _ in range(0, 2):
        result = requests.get(url)
        if result.status_code <> 200:
            print(f'''Iteration {i} failed. Application test failed with code {result.status_code}.''')

def main(args):
    client = docker.from_env()
    container = start_container(client, args.image, args.basedir)
    exit_code, output = container.exec_run('./02_set_process_id.sh ./03_start_processes.sh')
    print(exit_code, output)
    sleep(5)
    test_software(0, args.url)
    exit_code, output = container.exec_run('./04_dump_processes.sh')
    print(exit_code, output)
    sleep(5)
    container.kill()
    container.stop()

    for i in range(1, args.loops):
        container = start_container(client, args.image, args.basedir)
        exit_code, output = container.exec_run('./05_restore_processes.sh')
        sleep(1)
        test_software(i, args.url)
        container.kill()
        container.stop()
        if exit_code <> 0:
            print(f'''Iteration {i} failed. Couldn't restore.''')
            exit(1)


def parse_arguments():
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-l', '--loops', type=int, help='Loops', default=512)
    parser.add_argument('-i', '--image', help='Docker image', default='criu-x11-poc')
    parser.add_argument('-b', '--basedir', help='Base directory', default=os.getcwd())
    parser.add_argument('-u', '--url', help='App test URL', default='http://localhost:8080/')
    return parser.parse_args()


if __name__ == '__main__':
    main(parse_arguments())
