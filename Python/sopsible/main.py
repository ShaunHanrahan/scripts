import os
import yaml
from ansible.parsing.vault import VaultLib, VaultSecret
from ansible.parsing.dataloader import DataLoader
from ansible.errors import AnsibleError

def find_yaml_files(path):
    yaml_files = []
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith('.yaml') or file.endswith('.yaml'):
                yaml_files.append(os.path.join(root, file))
    return yaml_files

def decrypt_vault_file(file_path, password):
    loader = DataLoader()
    secret = VaultSecret(bytes(password, 'utf-8'))
    vault = VaultLib([(None, secret)])

    try:
        data = loader.load_from_file(file_path)
        decrypted_data = {}
        for key, value in data.items():
            if isinstance(value, str) and value.startswith('$ANSIBLE_VAULT;'):
                decrypted_value = vault.decrypt(value)
                decrypted_data[key] = decrypted_value.decode('utf-8')
        return decrypted_data
    except AnsibleError as e:
        print(f'Error decrypting {file_path}: {e}')
        return None

def write_decrypted_secrets(output_file, file_path, decrypted_data):
    with open(output_file, 'a') as f:
        f.write(f'File: {file_path}\n')
        for key, value in decrypted_data.items():
            f.write(f'{key}: {value}\n')
        f.write('\n')

def main():
    password = input('Enter the Ansible Vault password: ')
    search_path = input('Enter the path to search for Vault files: ')
    output_file = input('Enter the output file path: ')

    yaml_files = find_yaml_files(search_path)

    for file in yaml_files:
        decrypted_data = decrypt_vault_file(file, password)
        if decrypted_data:
            write_decrypted_secrets(output_file, file, decrypted_data)

if __name__ == '__main__':
    main()