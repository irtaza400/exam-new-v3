# Troubleshooting

## Docker permission denied
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Port already used
```bash
sudo lsof -i :3000
sudo lsof -i :8086
sudo lsof -i :1883
```

## Python package issue
```bash
source venv/bin/activate
pip install -r requirements.txt
```
