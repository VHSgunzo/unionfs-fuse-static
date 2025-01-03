# unionfs-fuse-static
Statically linked [unionfs-fuse](https://github.com/rpodgorny/unionfs-fuse)

## To get started:
* **Download the latest revision**
```
git clone https://github.com/VHSgunzo/unionfs-fuse-static.git
cd unionfs-fuse-static
```

* **Compile the binaries**
```
# for x86_64
docker run --rm -it -v "$PWD:/root" --platform=linux/amd64 ubuntu:jammy /root/build.sh

# for aarch64 (required qemu-user-static)
docker run --rm -it -v "$PWD:/root" --platform=linux/arm64 ubuntu:jammy /root/build.sh
```

* Or take an already precompiled from the [releases](https://github.com/VHSgunzo/unionfs-fuse-static/releases)
