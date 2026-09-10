import subprocess
print(subprocess.run('docker build containers/dev-dotfiles-debian', shell=True, capture_output=True).stderr.decode())
