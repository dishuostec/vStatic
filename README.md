# vStatic

A tiny (241KB) static web server, written in [v](https://vlang.io/).

## Build

```shell
v vStatic.v -prod -skip-unused
chmod +x vStatic 
```

## Usage
```
./vStatic

Serving /Users/dishuostec/wwwroot on http://localhost:8080
```

## Options
```shell
./vStatic --help

vStatic v0.0.1
-----------------------------------------------
Usage: vStatic [options]

This application does not expect any arguments

Options:
  -p, --port <int>          port
  -h, --host <string>       hostname
  -r, --root <string>       root dir
  -b, --base <string>       base url
  -h, --help                display this help and exit
  --version                 output version information and exit
  ```

## FAQ

### Library not loaded: /usr/local/opt/openssl@3/lib/libssl.3.dylib

Install latest openssl.
```shell
brew install openssl
```