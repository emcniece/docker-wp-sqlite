# Docker WordPress SQLite

A Docker image for running WordPress on a SQLite backend

## Usage

Basic:

```sh
docker run -d emcniece/wp-sqlite
```

With port and volume:

```sh
docker run -d -p 8080:80 -v ./www:/var/www emcniece/wp-sqlite
```

### Rancher

See Rancher catalog at https://github.com/emcniece/rancher-catalog