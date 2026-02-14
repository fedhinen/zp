# zp

`zp` es una utilidad para copiar archivos usando reflink en sistemas de archivos btrfs/xfs

## Instalacion

### Binarios precompilados
```bash
wget https://github.com/user/zp/releases/download/v1.0.2/zp-v1.0.2-linux-x86_64.tar.gz
tar -xzf zp-v1.0.2-linux-x86_64.tar.gz
sudo install zp-v1.0.2-linux-x86_64/zp /usr/local/bin/
```

### Codigo fuente
```bash
git clone https://github.com/fedhinen/zp
cd zp
zig build -Doptimize=ReleaseFast
sudo mv zig-out/bin/zp /usr/local/bin/
```

## Uso
```bash
zp source_file dest_file
```

## Benchmarks
En btrfs con un archivo de 356MB:
- `cp --reflink`: 5.4ms
- `zp`: 4.9ms (10% mas rapido)
