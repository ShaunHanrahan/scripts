"""
Conversion script for docker-compose.yml to the Ansible module community.docker.docker_container
"""

import argparse

import yaml

SERVICE_KEYS = {
    "container_name": "name",
    "image": "image",
    "command": "command",
    "environment": "env",
    "volumes": "volumes",
    "ports": "ports",
    "depends_on": "depends_on",
    "restart": "restart_policy",
    "env_file": "env_file",
    "cap_add": "capabilities",
    "cap_drop": "cap_drop",
}

VOLUME_KEYS = {
    "name": "name",
    "driver": "driver",
    "driver_opts": "driver_opts",
    "labels": "labels",
}

NETWORK_KEYS = {
    "name": "name",
    "driver": "driver",
    "driver_opts": "driver_opts",
    "attachable": "attachable",
    "enable_ipv6": "enable_ipv6",
    # "ipam": "ipam", # TODO: IPAM config not supported.
    "internal": "internal",
    "labels": "labels",
}

SUPPORTED_META_SPECS = ['volume', 'network']


# https://stackoverflow.com/a/39681672/5209106
class MyDumper(yaml.Dumper): # pylint: disable=too-many-ancestors
    """Custom YAML dumper to fix list indentation"""
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)

def represent_none(self, _):
    return self.represent_scalar('tag:yaml.org,2002:null', '')

yaml.add_representer(type(None), represent_none)

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--input_file',
        help='Path to docker-compose file',
        default='compose.yml',
        type=str
    )
    parser.add_argument(
        '--output_file',
        help='Path to output file',
        default='ansible-container.yml',
        type=str
    )
    parser.add_argument(
        '--output_type',
        help='Output type. One of "tasks" or "list"',
        default='list',
        type=str
    )
    args = parser.parse_args()
    if args.output_type not in ['tasks', 'list']:
        raise ValueError("Output type must be 'tasks' or 'list'")
    return args


def extract_service_sysctls(sysctls: dict) -> dict:
    """Transpose sysctls from dict to list"""
    input = sysctls
    return_data = {}
    if isinstance(sysctls, dict):
        for i in sysctls.items():
            parts = i.split('=', maxsplit=1)
            return_data[parts[0]] = parts[1]
    elif isinstance(sysctls, list):
        for i in sysctls:
            parts = i.split('=', maxsplit=1)
            return_data[parts[0]] = parts[1]
    return return_data

def extract_service_environment(environment) -> dict:
    """Transpose environment from dict to list"""
    return_data = {}
    
    # If the input is already a dictionary, simply return it.
    if isinstance(environment, dict):
        return environment
    
    # If the input is a list, process each item.
    elif isinstance(environment, list):
        for item in environment:
            parts = item.split('=', maxsplit=1)
            
            # If there's no '=', set the value as an empty string.
            if len(parts) == 1:
                return_data[parts[0].strip()] = ''
            else:
                return_data[parts[0].strip()] = parts[1].strip()
                
    return return_data

def extract_services(compose_services: dict, output_type: str) -> list:
    """Extract compose service data and convert for Ansible module compatibility"""
    services = []
    return_dat = []

    for service, options in compose_services.items():
        service_conf = {SERVICE_KEYS[k]: v for k, v in options.items() if k in SERVICE_KEYS}

        if not service_conf.get('name'):
            service_conf['name'] = service

        if options.get('networks'):
            service_conf['networks'] = list(options['networks'])

        if options.get('sysctls'):
            service_conf['sysctls'] = extract_service_sysctls(options['sysctls'])

        if options.get('environment'):
            service_conf['environment'] = extract_service_environment(options['environment'])

        services.append(service_conf)

    if output_type == 'tasks':
        return_dat = [
            {
                'name': f"Deploy {service['name']} container",
                'community.docker.docker_container': {**service, 'state': 'present'}
            }
            for service in services
        ]
    elif output_type == 'list':
        return_dat = services

    return return_dat


def extract_meta(input_data: dict, output_type: str, spec: str) -> list:
    """Extract compose meta configs and convert for Ansible module compatibility"""
    if spec not in SUPPORTED_META_SPECS:
        raise ValueError(f"Invalid spec: {spec}. Must be one of {SUPPORTED_META_SPECS}")

    extracted_data = []
    return_data = []
    spec_keys = globals()[spec.upper() + "_KEYS"]

    for name, options in input_data.items():
        conf = {}
        if options:
            conf = {
                spec_keys[k]: v for k, v in options.items() if k != 'external' and k in spec_keys
            }
            # TODO: add output if key missing and therefore missing

        if not conf.get('name'):
            conf['name'] = name

        extracted_data.append(conf)

    if output_type == 'tasks':
        return_data = [
            {
                'name': f"Create {conf['name']} {spec}",
                f'community.docker.docker_{spec}': {**conf, 'state': 'present'}
            }
            for conf in extracted_data
        ]

    elif output_type == 'list':
        return_data = extracted_data

    return return_data


# TODO: env returns as list (sometimes?), should be dict
def main():
    """Main tiiing"""
    args = parse_arguments()

    with open(args.input_file, encoding='utf-8') as input_file:
        input_data = yaml.safe_load(input_file)

        if float(input_data['version']) < 3:
            raise ValueError(f"Unsupported Compose spec version: {input_data['version']}")

        extracted_data = {
            'services': extract_services(
                input_data.get('services', {}),
                args.output_type
            ),
            'volumes': extract_meta(
                input_data.get('volumes', {}),
                args.output_type,
                'volume'
            ),
            'networks': extract_meta(
                input_data.get('networks', {}),
                args.output_type,
                'network'
            )
        }

    with open(args.output_file, 'w', encoding='utf-8') as output_file:
        yaml.dump(extracted_data, output_file, indent=2, Dumper=MyDumper, sort_keys=False)


if __name__ == '__main__':
    main()
